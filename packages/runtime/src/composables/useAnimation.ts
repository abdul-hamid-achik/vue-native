import { NativeBridge } from '../bridge'

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
  offset: number  // 0.0 – 1.0
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

// ─── useAnimation composable ──────────────────────────────────────────────

/**
 * Imperative animation API backed by native UIView/CALayer animations.
 *
 * @example
 * const { timing, spring, keyframe, sequence, parallel } = useAnimation()
 *
 * // Fade in
 * await timing(viewId, { opacity: 1 }, { duration: 300 })
 *
 * // Spring bounce
 * await spring(viewId, { translateY: 0 }, { tension: 40, friction: 7 })
 *
 * // Keyframe flash
 * await keyframe(viewId, [
 *   { offset: 0, opacity: 1 },
 *   { offset: 0.5, opacity: 0 },
 *   { offset: 1, opacity: 1 },
 * ], { duration: 600 })
 *
 * // Sequence: fade then slide
 * await sequence([
 *   { type: 'timing', viewId, toStyles: { opacity: 0 }, options: { duration: 200 } },
 *   { type: 'timing', viewId, toStyles: { translateX: 100 }, options: { duration: 300 } },
 * ])
 *
 * // Parallel: fade + scale at once
 * await parallel([
 *   { type: 'timing', viewId, toStyles: { opacity: 0 }, options: { duration: 300 } },
 *   { type: 'spring', viewId, toStyles: { scale: 0 }, options: { tension: 50, friction: 10 } },
 * ])
 */
export function useAnimation() {
  function timing(viewId: number, toStyles: Record<string, any>, config: TimingConfig = {}): Promise<void> {
    return NativeBridge.invokeNativeModule('Animation', 'timing', [viewId, toStyles, config])
  }

  function spring(viewId: number, toStyles: Record<string, any>, config: SpringConfig = {}): Promise<void> {
    return NativeBridge.invokeNativeModule('Animation', 'spring', [viewId, toStyles, config])
  }

  function keyframe(viewId: number, steps: KeyframeStep[], config: { duration?: number } = {}): Promise<void> {
    return NativeBridge.invokeNativeModule('Animation', 'keyframe', [viewId, steps, config])
  }

  function sequence(animations: SequenceAnimation[]): Promise<void> {
    return NativeBridge.invokeNativeModule('Animation', 'sequence', [animations])
  }

  function parallel(animations: SequenceAnimation[]): Promise<void> {
    return NativeBridge.invokeNativeModule('Animation', 'parallel', [animations])
  }

  /** Convenience: fade a view to opacity 0 then remove or hide */
  function fadeOut(viewId: number, duration = 300): Promise<void> {
    return timing(viewId, { opacity: 0 }, { duration })
  }

  /** Convenience: fade a view in to opacity 1 */
  function fadeIn(viewId: number, duration = 300): Promise<void> {
    return timing(viewId, { opacity: 1 }, { duration })
  }

  /** Convenience: slide a view in from the right */
  function slideInFromRight(viewId: number, duration = 300): Promise<void> {
    return timing(viewId, { translateX: 0 }, { duration, easing: 'easeOut' })
  }

  /** Convenience: slide a view out to the right */
  function slideOutToRight(viewId: number, duration = 300): Promise<void> {
    return timing(viewId, { translateX: 400 }, { duration, easing: 'easeIn' })
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
    Easing,
  }
}
