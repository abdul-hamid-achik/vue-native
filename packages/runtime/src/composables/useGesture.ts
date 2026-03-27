import { ref, onUnmounted, type Ref } from '@vue/runtime-core'
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
}

export interface GestureHandler {
  id: symbol
  event: string
  config: GestureConfig
  callback: (state: GestureState) => void
}

type AnimatableNode = NativeNode | { id: number }
type GestureTargetRef = Ref<AnimatableNode | null | undefined>
type GestureTarget = number | GestureTargetRef | AnimatableNode

function hasViewId(value: unknown): value is { id: number } {
  return typeof value === 'object'
    && value !== null
    && 'id' in value
    && typeof (value as { id?: unknown }).id === 'number'
}

function isGestureRef(target: GestureTarget): target is GestureTargetRef {
  return typeof target === 'object' && target !== null && 'value' in target
}

function resolveViewId(target: GestureTarget): number {
  if (typeof target === 'number') return target
  if (isGestureRef(target)) {
    const val = target.value
    if (hasViewId(val)) return val.id
    throw new Error('[useGesture] Target ref has no .value.id — is the ref attached to a component?')
  }
  if (hasViewId(target)) return target.id
  throw new Error('[useGesture] Invalid target. Pass a number, template ref, or NativeNode.')
}

class GestureManager {
  private nodeId: number | null = null
  private handlers: Map<string, Set<(state: unknown) => void>> = new Map()
  private disposables: Array<() => void> = []

  attach(target: GestureTarget): void {
    this.nodeId = resolveViewId(target)
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

    NativeBridge.addEventListener(this.nodeId, event, (payload: unknown) => {
      if (config?.enabled === false) return
      callback(payload as GestureEventMap[K])
    })

    const dispose = () => {
      this.handlers.get(event)?.delete(callback as (state: unknown) => void)
      if (this.nodeId) {
        NativeBridge.removeEventListener(this.nodeId, event)
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

  function attach(t: GestureTarget): void {
    manager.attach(t)
    setupListeners()
  }

  function detach(): void {
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
}

export function useComposedGestures(
  target: GestureTarget,
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
  manager.attach(target)

  const panConfig = typeof options.pan === 'object' ? options.pan : {}
  const pinchConfig = typeof options.pinch === 'object' ? options.pinch : {}
  const rotateConfig = typeof options.rotate === 'object' ? options.rotate : {}

  const cleanupFns: Array<() => void> = []

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

  onUnmounted(() => {
    for (const fn of cleanupFns) fn()
    manager.detach()
  })

  return {
    pan,
    pinch,
    rotate,
    gestureState,
    activeGesture,
    isGesturing,
    isPinchingAndRotating,
    isPanningAndPinching,
  }
}
