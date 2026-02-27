import { NativeBridge } from '../bridge'
import type { NativeNode } from '../node'
import type { Ref } from '@vue/runtime-core'

// ─── Easing constants ─────────────────────────────────────────────────────

export const Easing = {
  linear: 'linear',
  ease: 'ease',
  easeIn: 'easeIn',
  easeOut: 'easeOut',
  easeInOut: 'easeInOut',
} as const

export type EasingType = typeof Easing[keyof typeof Easing]

// ─── Types ────────────────────────────────────────────────────────────────

export interface TimingConfig {
  duration?: number
  easing?: EasingType
  delay?: number
}

export interface SpringConfig {
  tension?: number
  friction?: number
  mass?: number
  velocity?: number
  delay?: number
}

export interface KeyframeStep {
  offset: number // 0.0 – 1.0
  opacity?: number
  translateX?: number
  translateY?: number
  scale?: number
  scaleX?: number
  scaleY?: number
}

export interface SequenceAnimation {
  type: 'timing' | 'spring'
  viewId: number
  toStyles: Record<string, any>
  options: TimingConfig | SpringConfig
}

// Keep backward-compat aliases for the old interface names
export type TimingOptions = TimingConfig
export type SpringOptions = SpringConfig

/**
 * Accepted view target for animation methods.
 * - `number` — raw node ID (backward compatible)
 * - `Ref` — a Vue template ref whose `.value` has an `id` (NativeNode)
 * - `NativeNode` — a node object directly
 *
 * @example
 * const myView = ref()  // template ref
 * await timing(myView, { opacity: 1 }, { duration: 300 })
 */
export type AnimationTarget = number | Ref<any> | NativeNode | { id: number }

/** Resolve an AnimationTarget to a numeric node ID. */
function resolveViewId(target: AnimationTarget): number {
  if (typeof target === 'number') return target
  // Ref<NativeNode> — unwrap .value
  if (target && typeof target === 'object' && 'value' in target) {
    const val = (target as Ref<any>).value
    if (val && typeof val.id === 'number') return val.id
    throw new Error('[VueNative] Animation target ref has no .value.id — is the ref attached to a component?')
  }
  // NativeNode or { id: number }
  if (target && typeof (target as any).id === 'number') return (target as any).id
  throw new Error('[VueNative] Invalid animation target. Pass a number, template ref, or NativeNode.')
}

// ─── useAnimation composable ──────────────────────────────────────────────

/**
 * Imperative animation API backed by native UIView/CALayer animations.
 *
 * All methods accept either a raw node ID (number), a template ref, or
 * a NativeNode object as the first argument.
 *
 * @example
 * const myView = ref()  // <VView ref="myView" ...>
 * const { timing, spring, fadeIn } = useAnimation()
 *
 * // Using template ref (recommended)
 * await timing(myView, { opacity: 1 }, { duration: 300 })
 *
 * // Using raw node ID (still works)
 * await timing(42, { opacity: 1 }, { duration: 300 })
 *
 * // Spring bounce
 * await spring(myView, { translateY: 0 }, { tension: 40, friction: 7 })
 *
 * // Keyframe flash
 * await keyframe(myView, [
 *   { offset: 0, opacity: 1 },
 *   { offset: 0.5, opacity: 0 },
 *   { offset: 1, opacity: 1 },
 * ], { duration: 600 })
 *
 * // Sequence: fade then slide
 * await sequence([
 *   { type: 'timing', viewId: resolveId(myView), toStyles: { opacity: 0 }, options: { duration: 200 } },
 *   { type: 'timing', viewId: resolveId(myView), toStyles: { translateX: 100 }, options: { duration: 300 } },
 * ])
 */
export function useAnimation() {
  function timing(target: AnimationTarget, toStyles: Record<string, any>, config: TimingConfig = {}): Promise<void> {
    return NativeBridge.invokeNativeModule('Animation', 'timing', [resolveViewId(target), toStyles, config])
  }

  function spring(target: AnimationTarget, toStyles: Record<string, any>, config: SpringConfig = {}): Promise<void> {
    return NativeBridge.invokeNativeModule('Animation', 'spring', [resolveViewId(target), toStyles, config])
  }

  function keyframe(target: AnimationTarget, steps: KeyframeStep[], config: { duration?: number } = {}): Promise<void> {
    return NativeBridge.invokeNativeModule('Animation', 'keyframe', [resolveViewId(target), steps, config])
  }

  function sequence(animations: SequenceAnimation[]): Promise<void> {
    return NativeBridge.invokeNativeModule('Animation', 'sequence', [animations])
  }

  function parallel(animations: SequenceAnimation[]): Promise<void> {
    return NativeBridge.invokeNativeModule('Animation', 'parallel', [animations])
  }

  /** Convenience: fade a view to opacity 0 then remove or hide */
  function fadeOut(target: AnimationTarget, duration = 300): Promise<void> {
    return timing(target, { opacity: 0 }, { duration })
  }

  /** Convenience: fade a view in to opacity 1 */
  function fadeIn(target: AnimationTarget, duration = 300): Promise<void> {
    return timing(target, { opacity: 1 }, { duration })
  }

  /** Convenience: slide a view in from the right */
  function slideInFromRight(target: AnimationTarget, duration = 300): Promise<void> {
    return timing(target, { translateX: 0 }, { duration, easing: 'easeOut' })
  }

  /** Convenience: slide a view out to the right */
  function slideOutToRight(target: AnimationTarget, duration = 300): Promise<void> {
    return timing(target, { translateX: 400 }, { duration, easing: 'easeIn' })
  }

  /**
   * Helper to resolve a target to a numeric ID for use in SequenceAnimation arrays.
   * @example
   * await sequence([
   *   { type: 'timing', viewId: resolveId(myRef), toStyles: {...}, options: {...} },
   * ])
   */
  function resolveId(target: AnimationTarget): number {
    return resolveViewId(target)
  }

  return {
    timing,
    spring,
    keyframe,
    sequence,
    parallel,
    fadeIn,
    fadeOut,
    slideInFromRight,
    slideOutToRight,
    resolveId,
    Easing,
  }
}
