import { ref, watch, onUnmounted, type Ref } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'
import type { NativeNode } from '../node'

export interface PanGestureState {
  translationX: number
  translationY: number
  velocityX: number
  velocityY: number
  state: 'began' | 'changed' | 'ended' | 'cancelled'
}

export interface PinchGestureState {
  scale: number
  velocity: number
  state: 'began' | 'changed' | 'ended' | 'cancelled'
}

export interface RotateGestureState {
  rotation: number
  velocity: number
  state: 'began' | 'changed' | 'ended' | 'cancelled'
}

export interface SwipeGestureState {
  direction: 'left' | 'right' | 'up' | 'down'
  locationX: number
  locationY: number
}

export interface TapGestureState {
  locationX: number
  locationY: number
  tapCount: number
}

export interface ForceTouchState {
  force: number
  locationX: number
  locationY: number
  stage: number
}

export interface HoverState {
  locationX: number
  locationY: number
  state: 'entered' | 'moved' | 'exited'
}

export type GestureState =
  | PanGestureState
  | PinchGestureState
  | RotateGestureState
  | SwipeGestureState
  | TapGestureState
  | ForceTouchState
  | HoverState

export interface GestureConfig {
  enabled?: boolean
  simultaneousGestures?: string[]
  exclusiveGestures?: string[]
  threshold?: number
  minPointers?: number
  maxPointers?: number
  waitFor?: Ref<GestureHandler | null>[]
  /**
   * Drive this gesture's visual transform on the native UI thread instead of
   * round-tripping through JS each frame. Currently supported for `pan`
   * (applies translationX/Y to the view's transform as the finger moves). The
   * JS callback still fires for state tracking and `ended` handling.
   */
  nativeDrive?: boolean
}

export interface GestureHandler {
  id: symbol
  event: string
  config: GestureConfig
  callback: (state: GestureState) => void
}

type AnimatableNode = NativeNode | { id: number }
/**
 * The shape a template ref on a component actually resolves to: Vue's `setRef`
 * stores the component's public instance, whose `$el` is the root native node.
 */
type ComponentInstanceLike = { $el: AnimatableNode | null | undefined }
type GestureTargetRef = Ref<AnimatableNode | ComponentInstanceLike | null | undefined>
type GestureTarget = number | GestureTargetRef | AnimatableNode | ComponentInstanceLike

function hasViewId(value: unknown): value is { id: number } {
  return typeof value === 'object'
    && value !== null
    && 'id' in value
    && typeof (value as { id?: unknown }).id === 'number'
}

function isGestureRef(target: GestureTarget): target is GestureTargetRef {
  return typeof target === 'object' && target !== null && 'value' in target
}

/**
 * Extract a native view id from a resolved target value, or `null` when the
 * value carries none.
 *
 * A template ref on a component (`<VView ref="viewRef">`) does not resolve to
 * the native node: Vue's `setRef` stores the component's public instance
 * proxy, whose `$el` is the component's root element. Accepting both shapes is
 * what makes the documented `useGesture(viewRef)` pattern attach at all.
 */
function viewIdOf(value: unknown): number | null {
  if (hasViewId(value)) return value.id
  if (typeof value === 'object' && value !== null && '$el' in value) {
    const el = (value as { $el?: unknown }).$el
    if (hasViewId(el)) return el.id
  }
  return null
}

/**
 * Resolve a target to a native view id, or `null` when the target is a template
 * ref that has not been populated yet.
 *
 * A null ref during `setup()` is a timing fact, not a mistake: Vue fills template
 * refs after the first render. The old `resolveViewId` threw here, so the
 * documented `useGesture(viewRef)` / `useComposedGestures(viewRef)` pattern
 * crashed during setup instead of waiting for the view to exist. Callers now
 * defer and retry through a watcher.
 */
function tryResolveViewId(target: GestureTarget): number | null {
  if (typeof target === 'number') return target
  if (isGestureRef(target)) {
    const val = target.value
    if (val == null) return null
    const id = viewIdOf(val)
    if (id !== null) return id
    throw new Error('[useGesture] Target ref has no .value.id — is the ref attached to a component?')
  }
  const id = viewIdOf(target)
  if (id !== null) return id
  throw new Error('[useGesture] Invalid target. Pass a number, template ref, or NativeNode.')
}

class GestureManager {
  private nodeId: number | null = null
  private handlers: Map<string, Set<(state: unknown) => void>> = new Map()
  private disposables: Array<() => void> = []
  private nativeDriven: Set<string> = new Set()

  /**
   * Bind to a target. Returns false when the target is a template ref that is
   * not populated yet, so the caller can defer instead of losing its listeners.
   */
  attach(target: GestureTarget): boolean {
    const id = tryResolveViewId(target)
    this.nodeId = id
    return id !== null
  }

  /** Push the set of native-driven gesture names to the view as a prop. */
  private syncNativeDriven(): void {
    if (this.nodeId) {
      NativeBridge.updateProp(this.nodeId, 'nativeDrivenGestures', [...this.nativeDriven])
    }
  }

  on<K extends keyof GestureEventMap>(
    event: K,
    callback: (state: GestureEventMap[K]) => void,
    config?: GestureConfig,
  ): () => void {
    if (!this.nodeId) {
      console.warn('[useGesture] Cannot add listener: not attached to a view. Call attach() first or use a ref.')
      return () => {}
    }

    if (!this.handlers.has(event)) {
      this.handlers.set(event, new Set())
    }
    this.handlers.get(event)!.add(callback as (state: unknown) => void)

    if (config?.nativeDrive) {
      this.nativeDriven.add(event)
      this.syncNativeDriven()
    }

    // The bridge supports multiple subscribers per (node, event); keep a
    // reference to this listener so dispose removes it without knocking out
    // other bindings (e.g. the declarative option refs plus a manual on()).
    const listener = (payload: unknown) => {
      if (config?.enabled === false) return
      callback(payload as GestureEventMap[K])
    }
    NativeBridge.addEventListener(this.nodeId, event, listener)

    const dispose = () => {
      this.handlers.get(event)?.delete(callback as (state: unknown) => void)
      if (this.nodeId) {
        NativeBridge.removeEventListener(this.nodeId, event, listener)
      }
      if (this.nativeDriven.delete(event)) {
        this.syncNativeDriven()
      }
    }
    this.disposables.push(dispose)
    return dispose
  }

  detach(): void {
    for (const dispose of this.disposables) {
      dispose()
    }
    this.disposables = []
    this.handlers.clear()
    this.nativeDriven.clear()
    this.nodeId = null
  }
}

interface GestureEventMap {
  pan: PanGestureState
  pinch: PinchGestureState
  rotate: RotateGestureState
  swipeLeft: SwipeGestureState
  swipeRight: SwipeGestureState
  swipeUp: SwipeGestureState
  swipeDown: SwipeGestureState
  press: TapGestureState
  longPress: TapGestureState
  doubleTap: TapGestureState
  forceTouch: ForceTouchState
  hover: HoverState
}

type AnyGestureState = PanGestureState | PinchGestureState | RotateGestureState | SwipeGestureState | TapGestureState | ForceTouchState | HoverState

export interface UseGestureReturn {
  pan: Ref<PanGestureState | null>
  pinch: Ref<PinchGestureState | null>
  rotate: Ref<RotateGestureState | null>
  swipeLeft: Ref<SwipeGestureState | null>
  swipeRight: Ref<SwipeGestureState | null>
  swipeUp: Ref<SwipeGestureState | null>
  swipeDown: Ref<SwipeGestureState | null>
  press: Ref<TapGestureState | null>
  longPress: Ref<TapGestureState | null>
  doubleTap: Ref<TapGestureState | null>
  forceTouch: Ref<ForceTouchState | null>
  hover: Ref<HoverState | null>
  gestureState: Ref<AnyGestureState | null>
  activeGesture: Ref<string | null>
  isGesturing: Ref<boolean>
  attach: (target: GestureTarget) => void
  detach: () => void
  on: <K extends keyof GestureEventMap>(event: K, callback: (state: GestureEventMap[K]) => void) => () => void
}

export interface UseGestureOptions {
  pan?: boolean | GestureConfig
  pinch?: boolean | GestureConfig
  rotate?: boolean | GestureConfig
  swipeLeft?: boolean | GestureConfig
  swipeRight?: boolean | GestureConfig
  swipeUp?: boolean | GestureConfig
  swipeDown?: boolean | GestureConfig
  press?: boolean | GestureConfig
  longPress?: boolean | GestureConfig
  doubleTap?: boolean | GestureConfig
  forceTouch?: boolean | GestureConfig
  hover?: boolean | GestureConfig
  simultaneousGestures?: string[]
}

export function useGesture(target?: GestureTarget, options: UseGestureOptions = {}): UseGestureReturn {
  const pan = ref<PanGestureState | null>(null)
  const pinch = ref<PinchGestureState | null>(null)
  const rotate = ref<RotateGestureState | null>(null)
  const swipeLeft = ref<SwipeGestureState | null>(null)
  const swipeRight = ref<SwipeGestureState | null>(null)
  const swipeUp = ref<SwipeGestureState | null>(null)
  const swipeDown = ref<SwipeGestureState | null>(null)
  const press = ref<TapGestureState | null>(null)
  const longPress = ref<TapGestureState | null>(null)
  const doubleTap = ref<TapGestureState | null>(null)
  const forceTouch = ref<ForceTouchState | null>(null)
  const hover = ref<HoverState | null>(null)
  const gestureState = ref<AnyGestureState | null>(null)
  const activeGesture = ref<string | null>(null)
  const isGesturing = ref(false)

  const manager = new GestureManager()
  const cleanupFns: Array<() => void> = []

  let stopTargetWatch: (() => void) | null = null
  let listenersActive = false

  function attach(t: GestureTarget): void {
    if (!manager.attach(t)) {
      // Template ref not populated yet. Vue fills refs after the first render, so
      // retry when the view appears instead of registering listeners against a
      // null node id — manager.on() hands back a no-op disposer in that case, so
      // the bindings would be lost permanently even after a later attach.
      if (isGestureRef(t)) watchTarget(t)
      return
    }
    activateListeners()
  }

  function watchTarget(t: GestureTargetRef): void {
    stopTargetWatch?.()
    stopTargetWatch = watch(t, (value) => {
      if (value == null || !manager.attach(t)) return
      stopTargetWatch?.()
      stopTargetWatch = null
      activateListeners()
    })
  }

  /** Register the native listeners exactly once per attach cycle. */
  function activateListeners(): void {
    if (listenersActive) return
    listenersActive = true
    setupListeners()
  }

  function detach(): void {
    stopTargetWatch?.()
    stopTargetWatch = null
    listenersActive = false
    for (const fn of cleanupFns) fn()
    cleanupFns.length = 0
    manager.detach()
    pan.value = null
    pinch.value = null
    rotate.value = null
    swipeLeft.value = null
    swipeRight.value = null
    swipeUp.value = null
    swipeDown.value = null
    press.value = null
    longPress.value = null
    doubleTap.value = null
    forceTouch.value = null
    hover.value = null
    gestureState.value = null
    activeGesture.value = null
    isGesturing.value = false
  }

  function normalizeConfig(opt: boolean | GestureConfig | undefined): GestureConfig {
    return typeof opt === 'boolean' ? { enabled: opt } : (opt ?? {})
  }

  function on<K extends keyof GestureEventMap>(
    event: K,
    callback: (state: GestureEventMap[K]) => void,
  ): () => void {
    return manager.on(event, callback)
  }

  function setupListeners(): void {
    if (options.pan) {
      const cfg = normalizeConfig(options.pan)
      const dispose = manager.on('pan', (state) => {
        pan.value = state
        gestureState.value = state
        activeGesture.value = 'pan'
        isGesturing.value = state.state === 'began' || state.state === 'changed'
      }, cfg)
      cleanupFns.push(dispose)
    }

    if (options.pinch) {
      const cfg = normalizeConfig(options.pinch)
      const dispose = manager.on('pinch', (state) => {
        pinch.value = state
        gestureState.value = state
        activeGesture.value = 'pinch'
        isGesturing.value = state.state === 'began' || state.state === 'changed'
      }, cfg)
      cleanupFns.push(dispose)
    }

    if (options.rotate) {
      const cfg = normalizeConfig(options.rotate)
      const dispose = manager.on('rotate', (state) => {
        rotate.value = state
        gestureState.value = state
        activeGesture.value = 'rotate'
        isGesturing.value = state.state === 'began' || state.state === 'changed'
      }, cfg)
      cleanupFns.push(dispose)
    }

    if (options.swipeLeft) {
      const cfg = normalizeConfig(options.swipeLeft)
      const dispose = manager.on('swipeLeft', (state) => {
        swipeLeft.value = state
        gestureState.value = state
        activeGesture.value = 'swipeLeft'
        isGesturing.value = false
      }, cfg)
      cleanupFns.push(dispose)
    }

    if (options.swipeRight) {
      const cfg = normalizeConfig(options.swipeRight)
      const dispose = manager.on('swipeRight', (state) => {
        swipeRight.value = state
        gestureState.value = state
        activeGesture.value = 'swipeRight'
        isGesturing.value = false
      }, cfg)
      cleanupFns.push(dispose)
    }

    if (options.swipeUp) {
      const cfg = normalizeConfig(options.swipeUp)
      const dispose = manager.on('swipeUp', (state) => {
        swipeUp.value = state
        gestureState.value = state
        activeGesture.value = 'swipeUp'
        isGesturing.value = false
      }, cfg)
      cleanupFns.push(dispose)
    }

    if (options.swipeDown) {
      const cfg = normalizeConfig(options.swipeDown)
      const dispose = manager.on('swipeDown', (state) => {
        swipeDown.value = state
        gestureState.value = state
        activeGesture.value = 'swipeDown'
        isGesturing.value = false
      }, cfg)
      cleanupFns.push(dispose)
    }

    if (options.press) {
      const cfg = normalizeConfig(options.press)
      const dispose = manager.on('press', (state) => {
        press.value = state
        gestureState.value = state
        activeGesture.value = 'press'
        isGesturing.value = false
      }, cfg)
      cleanupFns.push(dispose)
    }

    if (options.longPress) {
      const cfg = normalizeConfig(options.longPress)
      const dispose = manager.on('longPress', (state) => {
        longPress.value = state
        gestureState.value = state
        activeGesture.value = 'longPress'
        isGesturing.value = false
      }, cfg)
      cleanupFns.push(dispose)
    }

    if (options.doubleTap) {
      const cfg = normalizeConfig(options.doubleTap)
      const dispose = manager.on('doubleTap', (state) => {
        doubleTap.value = state
        gestureState.value = state
        activeGesture.value = 'doubleTap'
        isGesturing.value = false
      }, cfg)
      cleanupFns.push(dispose)
    }

    if (options.forceTouch) {
      const cfg = normalizeConfig(options.forceTouch)
      const dispose = manager.on('forceTouch', (state) => {
        forceTouch.value = state
        gestureState.value = state
        activeGesture.value = 'forceTouch'
        isGesturing.value = state.stage > 0
      }, cfg)
      cleanupFns.push(dispose)
    }

    if (options.hover) {
      const cfg = normalizeConfig(options.hover)
      const dispose = manager.on('hover', (state) => {
        hover.value = state
        gestureState.value = state
        activeGesture.value = 'hover'
        isGesturing.value = state.state !== 'exited'
      }, cfg)
      cleanupFns.push(dispose)
    }
  }

  onUnmounted(() => {
    detach()
  })

  if (target !== undefined) {
    attach(target)
  }

  return {
    pan,
    pinch,
    rotate,
    swipeLeft,
    swipeRight,
    swipeUp,
    swipeDown,
    press,
    longPress,
    doubleTap,
    forceTouch,
    hover,
    gestureState,
    activeGesture,
    isGesturing,
    attach,
    detach,
    on,
  }
}

export interface GestureCompositionOptions {
  enabled?: Ref<boolean>
}

export interface ComposedGesture {
  pan: Ref<PanGestureState | null>
  pinch: Ref<PinchGestureState | null>
  rotate: Ref<RotateGestureState | null>
  gestureState: Ref<AnyGestureState | null>
  activeGesture: Ref<string | null>
  isGesturing: Ref<boolean>
  isPinchingAndRotating: Ref<boolean>
  isPanningAndPinching: Ref<boolean>
  /**
   * Bind to a view after construction, for when the target is not known during
   * setup. Passing an unpopulated template ref to the constructor also attaches
   * automatically once the view exists.
   */
  attach: (target: GestureTarget) => void
  detach: () => void
}

/**
 * Pan + pinch + rotate on a single view, with the combined states precomputed.
 *
 * `target` is optional and may be a template ref that is still null during
 * `setup()`. It used to be required and attached eagerly, so
 * `useComposedGestures(viewRef)` threw during setup — and because
 * `GestureManager.on()` returns a no-op disposer while unattached, the pan,
 * pinch and rotate listeners were discarded permanently even once the view
 * appeared. Attachment is now deferred and retried through a watcher.
 */
export function useComposedGestures(
  target?: GestureTarget,
  options: GestureCompositionOptions & UseGestureOptions = {},
): ComposedGesture {
  const pan = ref<PanGestureState | null>(null)
  const pinch = ref<PinchGestureState | null>(null)
  const rotate = ref<RotateGestureState | null>(null)
  const gestureState = ref<AnyGestureState | null>(null)
  const activeGesture = ref<string | null>(null)
  const isGesturing = ref(false)
  const isPinchingAndRotating = ref(false)
  const isPanningAndPinching = ref(false)

  const manager = new GestureManager()

  const panConfig = typeof options.pan === 'object' ? options.pan : {}
  const pinchConfig = typeof options.pinch === 'object' ? options.pinch : {}
  const rotateConfig = typeof options.rotate === 'object' ? options.rotate : {}

  const cleanupFns: Array<() => void> = []
  let stopTargetWatch: (() => void) | null = null
  let listenersActive = false

  function setupListeners(): void {
    if (options.pan !== false) {
      cleanupFns.push(manager.on('pan', (state) => {
        pan.value = state
        gestureState.value = state
        activeGesture.value = 'pan'
        isGesturing.value = state.state === 'began' || state.state === 'changed'
        isPanningAndPinching.value = pinch.value !== null && (state.state === 'began' || state.state === 'changed')
      }, panConfig))
    }

    if (options.pinch !== false) {
      cleanupFns.push(manager.on('pinch', (state) => {
        pinch.value = state
        gestureState.value = state
        activeGesture.value = 'pinch'
        isGesturing.value = state.state === 'began' || state.state === 'changed'
        isPinchingAndRotating.value = rotate.value !== null && (state.state === 'began' || state.state === 'changed')
        isPanningAndPinching.value = pan.value !== null && (state.state === 'began' || state.state === 'changed')
      }, pinchConfig))
    }

    if (options.rotate !== false) {
      cleanupFns.push(manager.on('rotate', (state) => {
        rotate.value = state
        gestureState.value = state
        activeGesture.value = 'rotate'
        isGesturing.value = state.state === 'began' || state.state === 'changed'
        isPinchingAndRotating.value = pinch.value !== null && (state.state === 'began' || state.state === 'changed')
      }, rotateConfig))
    }
  }

  /** Register the native listeners exactly once per attach cycle. */
  function activateListeners(): void {
    if (listenersActive) return
    listenersActive = true
    setupListeners()
  }

  function attach(t: GestureTarget): void {
    if (!manager.attach(t)) {
      if (isGestureRef(t)) watchTarget(t)
      return
    }
    activateListeners()
  }

  function watchTarget(t: GestureTargetRef): void {
    stopTargetWatch?.()
    stopTargetWatch = watch(t, (value) => {
      if (value == null || !manager.attach(t)) return
      stopTargetWatch?.()
      stopTargetWatch = null
      activateListeners()
    })
  }

  function detach(): void {
    stopTargetWatch?.()
    stopTargetWatch = null
    listenersActive = false
    for (const fn of cleanupFns) fn()
    cleanupFns.length = 0
    manager.detach()
    pan.value = null
    pinch.value = null
    rotate.value = null
    gestureState.value = null
    activeGesture.value = null
    isGesturing.value = false
    isPinchingAndRotating.value = false
    isPanningAndPinching.value = false
  }

  onUnmounted(() => {
    detach()
  })

  if (target !== undefined) {
    attach(target)
  }

  return {
    pan,
    pinch,
    rotate,
    gestureState,
    activeGesture,
    isGesturing,
    isPinchingAndRotating,
    isPanningAndPinching,
    attach,
    detach,
  }
}
