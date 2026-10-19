import { BaseTransition, defineComponent, h, ref, type VNode, type PropType } from '@vue/runtime-core'
import { useAnimation, Easing, type EasingType } from '../composables/useAnimation'

export type TransitionMode = 'in-out' | 'out-in' | 'default'

export interface TransitionProps {
  show?: boolean
  name?: string
  appear?: boolean
  persist?: boolean
  mode?: TransitionMode
  css?: boolean
  type?: 'transition' | 'animation'
  enterClass?: string
  leaveClass?: string
  enterActiveClass?: string
  leaveActiveClass?: string
  enterToClass?: string
  leaveToClass?: string
  enterFromClass?: string
  leaveFromClass?: string
  appearClass?: string
  appearActiveClass?: string
  appearToClass?: string
  duration?: number | { enter: number, leave: number, appear?: number }
  enterFrom?: Record<string, unknown>
  enterTo?: Record<string, unknown>
  leaveFrom?: Record<string, unknown>
  leaveTo?: Record<string, unknown>
  easing?: EasingType
}

const DefaultDuration = 300

function resolveAnimationTarget(el: unknown): number | undefined {
  if (!el) return undefined
  if (typeof el === 'number') return el
  if (typeof el === 'object' && 'id' in (el as object)) return (el as { id: number }).id
  return undefined
}

function getElementFromVNode(vnode: VNode): number | undefined {
  try {
    const el = vnode.el
    if (!el) return undefined
    return resolveAnimationTarget(el)
  } catch {
    return undefined
  }
}

function resolveTransitionTarget(el: unknown): number | undefined {
  return resolveAnimationTarget(el) ?? getElementFromVNode(el as VNode)
}

export const VTransition = defineComponent({
  name: 'VTransition',
  inheritAttrs: false,
  props: {
    show: { type: Boolean, default: true },
    name: { type: String, default: '' },
    appear: { type: Boolean, default: false },
    persist: { type: Boolean, default: false },
    mode: { type: String as PropType<TransitionMode>, default: 'default' },
    css: { type: Boolean, default: true },
    type: { type: String, default: 'transition' },
    enterClass: { type: String, default: '' },
    leaveClass: { type: String, default: '' },
    enterActiveClass: { type: String, default: '' },
    leaveActiveClass: { type: String, default: '' },
    enterToClass: { type: String, default: '' },
    leaveToClass: { type: String, default: '' },
    enterFromClass: { type: String, default: '' },
    leaveFromClass: { type: String, default: '' },
    appearClass: { type: String, default: '' },
    appearActiveClass: { type: String, default: '' },
    appearToClass: { type: String, default: '' },
    duration: [Number, Object] as PropType<number | { enter: number, leave: number, appear?: number }>,
    enterFrom: Object as PropType<Record<string, unknown>>,
    enterTo: Object as PropType<Record<string, unknown>>,
    leaveFrom: Object as PropType<Record<string, unknown>>,
    leaveTo: Object as PropType<Record<string, unknown>>,
    easing: { type: String as PropType<EasingType>, default: 'ease' },
  },
  setup(transitionProps, { slots, expose, attrs }) {
    const { timing } = useAnimation()
    const isAppearing = ref(false)
    const isLeaving = ref(false)
    const hasEntered = ref(!transitionProps.appear)

    // Per-element enter token. Bumped by every new doEnter, by doLeave and by
    // onEnterCancelled so a superseded enter chain can detect (between awaits)
    // that it is stale and must not touch the view anymore.
    // Tokens come from one increasing counter (never reused), so deleting an
    // entry can not make an old, stale chain look current again.
    const enterTokens = new Map<number, number>()
    let tokenSeq = 0

    function bumpToken(viewId: number): number {
      const next = ++tokenSeq
      enterTokens.set(viewId, next)
      return next
    }

    function enterDuration() {
      return typeof transitionProps.duration === 'object'
        ? (transitionProps.duration.enter ?? DefaultDuration)
        : (transitionProps.duration ?? DefaultDuration)
    }

    function enterToStyles() {
      return transitionProps.enterTo ?? presetStyles().enterTo
    }

    /**
     * Snap the element to its final enter style without animating. Used when an
     * enter chain fails or is cancelled so the view can never stay stuck at the
     * enterFrom style (e.g. opacity 0) because the second bridge call was lost.
     */
    function restoreEnterTo(viewId: number) {
      try {
        timing(viewId, enterToStyles(), { duration: 0 }).catch(() => {})
      } catch {
        // resolveViewId / bridge errors must never escape a transition hook
      }
    }

    function presetStyles() {
      if (transitionProps.name === 'slide') {
        return {
          enterFrom: { opacity: 0, translateX: -30 },
          enterTo: { opacity: 1, translateX: 0 },
          leaveFrom: { opacity: 1, translateX: 0 },
          leaveTo: { opacity: 0, translateX: -30 },
        }
      }

      return {
        enterFrom: { opacity: 0 },
        enterTo: { opacity: 1 },
        leaveFrom: { opacity: 1 },
        leaveTo: { opacity: 0 },
      }
    }

    function callListener(name: string, ...args: unknown[]) {
      const listener = attrs[name]
      if (Array.isArray(listener)) {
        listener.forEach(fn => typeof fn === 'function' && fn(...args))
      } else if (typeof listener === 'function') {
        listener(...args)
      }
    }

    async function doEnter(el: unknown) {
      const viewId = resolveTransitionTarget(el)
      if (viewId == null) return

      const token = bumpToken(viewId)
      const isCurrent = () => enterTokens.get(viewId) === token

      isAppearing.value = true

      const presets = presetStyles()
      const enterFrom = transitionProps.enterFrom ?? presets.enterFrom
      const enterTo = transitionProps.enterTo ?? presets.enterTo

      try {
        await timing(viewId, enterFrom, { duration: 0 })
        if (!isCurrent()) return
        await timing(viewId, enterTo, {
          duration: enterDuration(),
          easing: transitionProps.easing,
        })
        if (!isCurrent()) return
        enterTokens.delete(viewId)
        isAppearing.value = false
        hasEntered.value = true
      } catch (e) {
        if (!isCurrent()) return
        console.warn('[VueNative Transition] enter animation failed:', e)
        restoreEnterTo(viewId)
        isAppearing.value = false
        hasEntered.value = true
      }
    }

    async function doLeave(el: unknown) {
      const viewId = resolveTransitionTarget(el)
      if (viewId == null) return

      // Cancels any enter chain still in flight for this element.
      const leaveToken = bumpToken(viewId)
      isLeaving.value = true

      const leaveDuration = typeof transitionProps.duration === 'object'
        ? (transitionProps.duration.leave ?? DefaultDuration)
        : (transitionProps.duration ?? DefaultDuration)

      try {
        const presets = presetStyles()
        await timing(viewId, transitionProps.leaveFrom ?? presets.leaveFrom, { duration: 0 })
        await timing(viewId, transitionProps.leaveTo ?? presets.leaveTo, {
          duration: leaveDuration,
          easing: transitionProps.easing,
        })
      } catch (e) {
        console.warn('[VueNative Transition] leave animation failed:', e)
      } finally {
        isLeaving.value = false
        if (enterTokens.get(viewId) === leaveToken) enterTokens.delete(viewId)
      }
    }

    function onBeforeEnter(el: unknown) {
      callListener('onBeforeEnter', el)
    }

    function onEnter(el: unknown, done: () => void) {
      callListener('onEnter', el)
      doEnter(el).then(() => done())
    }

    function onLeave(el: unknown, done: () => void) {
      callListener('onLeave', el)
      doLeave(el).then(() => done())
    }

    function onAfterEnter() {
      callListener('onAfterEnter')
    }

    function onAfterLeave() {
      callListener('onAfterLeave')
    }

    function onEnterCancelled(el?: unknown) {
      isAppearing.value = false
      const viewId = el == null ? undefined : resolveTransitionTarget(el)
      if (viewId != null) {
        // Invalidate the running enter chain, then make sure the view is not
        // left at the enterFrom style. A leave (if any) starts afterwards with
        // its own leaveFrom style, so this snap never wins over it.
        bumpToken(viewId)
        restoreEnterTo(viewId)
      }
      callListener('onEnterCancelled', el)
    }

    function onLeaveCancelled() {
      isLeaving.value = false
      callListener('onLeaveCancelled')
    }

    function onAppear(el: unknown, done: () => void) {
      isAppearing.value = true
      callListener('onAppear', el)
      doEnter(el).then(() => done())
    }

    function onAfterAppear() {
      isAppearing.value = false
      callListener('onAfterAppear')
    }

    expose({
      onEnter,
      onBeforeEnter,
      onLeave,
      onAfterEnter,
      onAfterLeave,
      onEnterCancelled,
      onLeaveCancelled,
      onAppear,
      onAfterAppear,
      isAppearing,
      isLeaving,
      hasEntered,
    })

    return () => {
      const finalChildren = transitionProps.show ? (slots.default?.() ?? []) : []

      return h(BaseTransition, {
        name: transitionProps.name || 'v',
        appear: transitionProps.appear,
        persist: transitionProps.persist || transitionProps.name === 'persist',
        mode: transitionProps.mode === 'default' ? undefined : transitionProps.mode,
        css: transitionProps.css,
        type: transitionProps.type,
        onBeforeEnter,
        onEnter,
        onLeave,
        onAfterEnter,
        onAfterLeave,
        onEnterCancelled,
        onLeaveCancelled,
        onAppear,
        onAfterAppear,
      }, () => finalChildren)
    }
  },
})

export const VTransitionGroup = defineComponent({
  name: 'VTransitionGroup',
  props: {
    tag: { type: String, default: undefined },
    name: { type: String, default: 'v' },
    appear: { type: Boolean, default: false },
    persist: { type: Boolean, default: false },
    moveClass: { type: String, default: '' },
    duration: { type: Number, default: undefined },
  },
  setup(groupProps, { slots, expose }) {
    const { timing } = useAnimation()

    function onMove(_el: unknown) {
      // Move animations - handled natively
    }

    function onBeforeEnter(el: unknown) {
      const viewId = resolveTransitionTarget(el)
      if (viewId == null) return
      timing(viewId, { opacity: 0 }, { duration: 0 }).catch(() => {})
    }

    function onEnter(el: unknown, done: () => void) {
      const viewId = resolveTransitionTarget(el)
      if (viewId == null) {
        done()
        return
      }

      timing(viewId, { opacity: 1 }, { duration: groupProps.duration ?? 300, easing: 'easeOut' })
        .then(() => done())
        .catch(() => done())
    }

    function onLeave(el: unknown, done: () => void) {
      const viewId = resolveTransitionTarget(el)
      if (viewId == null) {
        done()
        return
      }

      timing(viewId, { opacity: 0 }, { duration: groupProps.duration ?? 300, easing: 'easeIn' })
        .then(() => done())
        .catch(() => done())
    }

    expose({
      onBeforeEnter,
      onEnter,
      onLeave,
      onMove,
    })

    return () => {
      const children = slots.default?.() ?? []
      return h(groupProps.tag || 'VView', {}, children.map((child, index) => h(BaseTransition, {
        key: child.key ?? index,
        name: groupProps.name,
        appear: groupProps.appear,
        persist: groupProps.persist,
        css: false,
        onBeforeEnter,
        onEnter,
        onLeave,
      }, () => [child])))
    }
  },
})

export { Easing }

export default {
  VTransition,
  VTransitionGroup,
  Easing,
}
