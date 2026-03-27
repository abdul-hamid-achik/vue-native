import { defineComponent, h, ref, type VNode, type PropType } from '@vue/runtime-core'
import { useAnimation, Easing } from '../composables/useAnimation'

export type TransitionMode = 'in-out' | 'out-in' | 'default'

export interface TransitionProps {
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
}

const DefaultDuration = 300

function resolveAnimationTarget(el: unknown): number | undefined {
  if (!el) return undefined
  if (typeof el === 'number') return el
  if (typeof el === 'object' && 'id' in (el as object)) return (el as { id: number }).id
  return undefined
}

export const VTransition = defineComponent({
  name: 'VTransition',
  props: {
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
  },
  setup(transitionProps, { slots, expose }) {
    const { timing } = useAnimation()
    const isAppearing = ref(false)
    const isLeaving = ref(false)
    const hasEntered = ref(!transitionProps.appear)

    function getElementFromVNode(vnode: VNode): number | undefined {
      try {
        const el = vnode.el
        if (!el) return undefined
        return resolveAnimationTarget(el)
      } catch {
        return undefined
      }
    }

    async function doEnter(el: unknown) {
      const viewId = getElementFromVNode(el as VNode)
      if (!viewId) return

      isAppearing.value = true

      const enterDuration = typeof transitionProps.duration === 'object'
        ? (transitionProps.duration.enter ?? DefaultDuration)
        : (transitionProps.duration ?? DefaultDuration)

      const enterStyles: Record<string, number> = { opacity: 1 }

      try {
        await timing(viewId, { opacity: 0 }, { duration: 0 })
        await timing(viewId, enterStyles, { duration: enterDuration, easing: 'easeOut' })
        isAppearing.value = false
        hasEntered.value = true
      } catch (e) {
        console.warn('[VueNative Transition] enter animation failed:', e)
        isAppearing.value = false
        hasEntered.value = true
      }
    }

    async function doLeave(el: unknown) {
      const viewId = getElementFromVNode(el as VNode)
      if (!viewId) return

      isLeaving.value = true

      const leaveDuration = typeof transitionProps.duration === 'object'
        ? (transitionProps.duration.leave ?? DefaultDuration)
        : (transitionProps.duration ?? DefaultDuration)

      try {
        await timing(viewId, { opacity: 0 }, { duration: leaveDuration, easing: 'easeIn' })
      } catch (e) {
        console.warn('[VueNative Transition] leave animation failed:', e)
      } finally {
        isLeaving.value = false
      }
    }

    function onEnter(_el: unknown, done: () => void) {
      if (!hasEntered.value || transitionProps.appear) {
        doEnter(_el).then(() => done())
      } else {
        done()
      }
    }

    function onLeave(el: unknown, done: () => void) {
      doLeave(el).then(() => done())
    }

    function onAfterEnter() {
      // Post-enter callback hook
    }

    function onAfterLeave() {
      // Post-leave callback hook
    }

    function onEnterCancelled() {
      isAppearing.value = false
    }

    function onLeaveCancelled() {
      isLeaving.value = false
    }

    function onAppear(el: unknown, done: () => void) {
      isAppearing.value = true
      doEnter(el).then(() => done())
    }

    function onAfterAppear() {
      isAppearing.value = false
    }

    expose({
      onEnter,
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
      const children = slots.default?.() ?? []
      const hasDefault = children.length > 0

      if (!hasDefault) {
        return h('', {}, [])
      }

      let finalChildren = children

      if (transitionProps.mode === 'out-in') {
        if (isLeaving.value) {
          finalChildren = [children[children.length - 1]]
        } else if (!hasEntered.value) {
          finalChildren = []
        }
      }

      if (transitionProps.mode === 'in-out') {
        if (isAppearing.value && children.length > 1) {
          finalChildren = [children[0]]
        }
      }

      return h('Transition', {
        name: transitionProps.name || 'v',
        appear: transitionProps.appear,
        persist: transitionProps.persist || transitionProps.name === 'persist',
        css: transitionProps.css,
        type: transitionProps.type,
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

    function onEnter(el: unknown, done: () => void) {
      const viewId = resolveAnimationTarget(el as { el: unknown })
      if (!viewId) {
        done()
        return
      }

      timing(viewId, { opacity: 1 }, { duration: groupProps.duration ?? 300, easing: 'easeOut' })
        .then(() => done())
        .catch(() => done())
    }

    function onLeave(el: unknown, done: () => void) {
      const viewId = resolveAnimationTarget(el as { el: unknown })
      if (!viewId) {
        done()
        return
      }

      timing(viewId, { opacity: 0 }, { duration: groupProps.duration ?? 300, easing: 'easeIn' })
        .then(() => done())
        .catch(() => done())
    }

    expose({
      onEnter,
      onLeave,
      onMove,
    })

    return () => {
      const children = slots.default?.() ?? []
      return h('TransitionGroup', {
        tag: groupProps.tag,
        name: groupProps.name,
        appear: groupProps.appear,
        persist: groupProps.persist,
        moveClass: groupProps.moveClass,
        onEnter,
        onLeave,
        onMove,
      }, () => children)
    }
  },
})

export { Easing }

export default {
  VTransition,
  VTransitionGroup,
  Easing,
}
