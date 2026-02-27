# useAnimation

Imperative animation API backed by native `UIView` animations on iOS and `ObjectAnimator` on Android. Supports timing, spring, keyframe, sequence, and parallel animations.

## Usage

```vue
<script setup>
import { useAnimation } from '@thelacanians/vue-native-runtime'

const { timing, spring, fadeIn, fadeOut } = useAnimation()
</script>
```

## AnimationTarget

All animation methods accept an `AnimationTarget` instead of a raw view ID. This lets you pass template refs, reactive refs, native nodes, or plain numeric IDs:

```ts
type AnimationTarget = number | Ref<any> | NativeNode | { id: number }
```

- `number` — a raw native node ID (e.g. `node.__nodeId`)
- `Ref<any>` — a template ref (e.g. `ref="boxRef"`)
- `NativeNode` — a native node object with an `id` property
- `{ id: number }` — any object with a numeric `id` field

The composable resolves the target internally via `resolveId()`.

## API

```ts
import { useAnimation, Easing } from '@thelacanians/vue-native-runtime'

useAnimation(): {
  timing: (target: AnimationTarget, toStyles: Record<string, any>, config?: TimingConfig) => Promise<void>
  spring: (target: AnimationTarget, toStyles: Record<string, any>, config?: SpringConfig) => Promise<void>
  keyframe: (target: AnimationTarget, steps: KeyframeStep[], config?: { duration?: number }) => Promise<void>
  sequence: (animations: SequenceAnimation[]) => Promise<void>
  parallel: (animations: SequenceAnimation[]) => Promise<void>
  fadeIn: (target: AnimationTarget, duration?: number) => Promise<void>
  fadeOut: (target: AnimationTarget, duration?: number) => Promise<void>
  slideInFromRight: (target: AnimationTarget, duration?: number) => Promise<void>
  slideOutToRight: (target: AnimationTarget, duration?: number) => Promise<void>
  resolveId: (target: AnimationTarget) => number
}
```

`Easing` is also exported as a top-level constant from the runtime package.

### Core Methods

#### `timing(target, toStyles, config?)`

Animate a view to the target styles using a timing curve.

| Parameter | Type | Description |
|-----------|------|-------------|
| `target` | `AnimationTarget` | The view to animate — a template ref, native node, node ID, or `{ id }` object. |
| `toStyles` | `Record<string, any>` | Target style properties (e.g. `{ opacity: 1, translateX: 100 }`). |
| `config` | `TimingConfig?` | Animation options. |

**TimingConfig:**

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `duration` | `number?` | `300` | Duration in milliseconds. |
| `easing` | `EasingType?` | `'ease'` | Easing curve. |
| `delay` | `number?` | `0` | Delay before starting in milliseconds. |

#### `spring(target, toStyles, config?)`

Animate a view using spring physics.

| Parameter | Type | Description |
|-----------|------|-------------|
| `target` | `AnimationTarget` | The view to animate — a template ref, native node, node ID, or `{ id }` object. |
| `toStyles` | `Record<string, any>` | Target style properties. |
| `config` | `SpringConfig?` | Spring configuration. |

**SpringConfig:**

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `tension` | `number?` | - | Spring tension (stiffness). |
| `friction` | `number?` | - | Spring friction (damping). |
| `mass` | `number?` | - | Mass of the animated object. |
| `velocity` | `number?` | - | Initial velocity. |
| `delay` | `number?` | `0` | Delay before starting in milliseconds. |

#### `keyframe(target, steps, config?)`

Run a multi-step keyframe animation on a view.

| Parameter | Type | Description |
|-----------|------|-------------|
| `target` | `AnimationTarget` | The view to animate — a template ref, native node, node ID, or `{ id }` object. |
| `steps` | `KeyframeStep[]` | Array of keyframe steps. Each step has an `offset` (0.0-1.0) and style properties. |
| `config` | `{ duration?: number }?` | Animation options. Duration defaults to `300` ms. |

**KeyframeStep:**

| Property | Type | Description |
|----------|------|-------------|
| `offset` | `number` | Position in the animation (0.0 to 1.0). |
| `opacity` | `number?` | Opacity value. |
| `translateX` | `number?` | Horizontal translation. |
| `translateY` | `number?` | Vertical translation. |
| `scale` | `number?` | Uniform scale. |
| `scaleX` | `number?` | Horizontal scale. |
| `scaleY` | `number?` | Vertical scale. |

#### `sequence(animations)`

Run multiple animations one after another.

| Parameter | Type | Description |
|-----------|------|-------------|
| `animations` | `SequenceAnimation[]` | Ordered list of animations to run sequentially. |

#### `parallel(animations)`

Run multiple animations simultaneously.

| Parameter | Type | Description |
|-----------|------|-------------|
| `animations` | `SequenceAnimation[]` | List of animations to run at the same time. |

**SequenceAnimation:**

| Property | Type | Description |
|----------|------|-------------|
| `type` | `'timing' \| 'spring'` | Animation type. |
| `target` | `AnimationTarget` | The view to animate. |
| `toStyles` | `Record<string, any>` | Target style properties. |
| `options` | `TimingConfig \| SpringConfig` | Animation configuration. |

### Convenience Methods

| Method | Description |
|--------|-------------|
| `fadeIn(target, duration?)` | Fade a view to opacity 1. Default duration: 300ms. |
| `fadeOut(target, duration?)` | Fade a view to opacity 0. Default duration: 300ms. |
| `slideInFromRight(target, duration?)` | Slide a view in from the right (translateX to 0). Default duration: 300ms. |
| `slideOutToRight(target, duration?)` | Slide a view out to the right (translateX to 400). Default duration: 300ms. |

### `resolveId(target)`

Utility to extract the numeric node ID from any `AnimationTarget`. Useful when you need the raw ID for `sequence` or `parallel` animations.

| Parameter | Type | Description |
|-----------|------|-------------|
| `target` | `AnimationTarget` | A template ref, native node, node ID, or `{ id }` object. |

Returns: `number` — the resolved native node ID.

### Easing Constants

Available via the `Easing` object returned by `useAnimation()`:

| Constant | Value | Description |
|----------|-------|-------------|
| `Easing.linear` | `'linear'` | Constant speed. |
| `Easing.ease` | `'ease'` | Default ease curve. |
| `Easing.easeIn` | `'easeIn'` | Accelerate from zero velocity. |
| `Easing.easeOut` | `'easeOut'` | Decelerate to zero velocity. |
| `Easing.easeInOut` | `'easeInOut'` | Accelerate then decelerate. |

### Animatable Properties

| Property | Description |
|----------|-------------|
| `opacity` | View opacity (0.0 to 1.0). |
| `translateX` | Horizontal translation in points. |
| `translateY` | Vertical translation in points. |
| `scale` | Uniform scale (maps to both scaleX and scaleY). |
| `scaleX` | Horizontal scale. |
| `scaleY` | Vertical scale. |

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses `UIView.animate` for timing, `UIView.animate(usingSpringWithDamping:)` for spring, and `CAKeyframeAnimation` for keyframes. |
| Android | Uses `ObjectAnimator` and `AnimatorSet`. Spring uses `OvershootInterpolator` as an approximation. |

## Example

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'
import { useAnimation } from '@thelacanians/vue-native-runtime'

const { timing, spring, keyframe, sequence, parallel, fadeIn, resolveId } = useAnimation()
const boxRef = ref(null)

async function animateFadeIn() {
  // Pass the template ref directly — no need to extract __nodeId manually
  await fadeIn(boxRef, 500)
}

async function animateBounce() {
  await spring(boxRef, { translateY: 0 }, { tension: 40, friction: 7 })
}

async function animateFlash() {
  await keyframe(boxRef, [
    { offset: 0, opacity: 1 },
    { offset: 0.5, opacity: 0 },
    { offset: 1, opacity: 1 },
  ], { duration: 600 })
}

async function animateSequence() {
  const id = resolveId(boxRef)
  await sequence([
    { type: 'timing', target: id, toStyles: { opacity: 0 }, options: { duration: 200 } },
    { type: 'timing', target: id, toStyles: { opacity: 1, translateX: 100 }, options: { duration: 300 } },
    { type: 'timing', target: id, toStyles: { translateX: 0 }, options: { duration: 300, easing: Easing.easeOut } },
  ])
}
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VView
      ref="boxRef"
      :style="{
        width: 100,
        height: 100,
        backgroundColor: '#4FC08D',
        borderRadius: 8,
      }"
    />
    <VButton :onPress="animateFadeIn"><VText>Fade In</VText></VButton>
    <VButton :onPress="animateBounce"><VText>Bounce</VText></VButton>
    <VButton :onPress="animateFlash"><VText>Flash</VText></VButton>
    <VButton :onPress="animateSequence"><VText>Sequence</VText></VButton>
  </VView>
</template>
```

## Notes

- All animation functions return a `Promise` that resolves when the animation completes.
- The `target` parameter accepts template refs, `Ref<any>`, `NativeNode`, `{ id: number }`, or a raw `number`. You no longer need to manually extract `__nodeId`.
- `Easing` is exported as both a top-level constant (`import { Easing } from '@thelacanians/vue-native-runtime'`) and as part of the `useAnimation()` return value.
- `sequence` runs animations one after another; `parallel` runs them all at once. Both resolve when all animations finish.
- On Android, spring animations use `OvershootInterpolator` as an approximation of true spring physics.
- Durations and delays are specified in milliseconds in the JS API but converted to seconds internally on the native side.
