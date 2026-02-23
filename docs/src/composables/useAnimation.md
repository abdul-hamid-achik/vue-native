# useAnimation

Imperative animation API backed by native `UIView` animations on iOS and `ObjectAnimator` on Android. Supports timing, spring, keyframe, sequence, and parallel animations.

## Usage

```vue
<script setup>
import { useAnimation } from '@thelacanians/vue-native-runtime'

const { timing, spring, fadeIn, fadeOut } = useAnimation()
</script>
```

## API

```ts
useAnimation(): {
  timing: (viewId: number, toStyles: Record<string, any>, config?: TimingConfig) => Promise<void>
  spring: (viewId: number, toStyles: Record<string, any>, config?: SpringConfig) => Promise<void>
  keyframe: (viewId: number, steps: KeyframeStep[], config?: { duration?: number }) => Promise<void>
  sequence: (animations: SequenceAnimation[]) => Promise<void>
  parallel: (animations: SequenceAnimation[]) => Promise<void>
  fadeIn: (viewId: number, duration?: number) => Promise<void>
  fadeOut: (viewId: number, duration?: number) => Promise<void>
  slideInFromRight: (viewId: number, duration?: number) => Promise<void>
  slideOutToRight: (viewId: number, duration?: number) => Promise<void>
  Easing: typeof Easing
}
```

### Core Methods

#### `timing(viewId, toStyles, config?)`

Animate a view to the target styles using a timing curve.

| Parameter | Type | Description |
|-----------|------|-------------|
| `viewId` | `number` | The native view ID to animate. |
| `toStyles` | `Record<string, any>` | Target style properties (e.g. `{ opacity: 1, translateX: 100 }`). |
| `config` | `TimingConfig?` | Animation options. |

**TimingConfig:**

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `duration` | `number?` | `300` | Duration in milliseconds. |
| `easing` | `EasingType?` | `'ease'` | Easing curve. |
| `delay` | `number?` | `0` | Delay before starting in milliseconds. |

#### `spring(viewId, toStyles, config?)`

Animate a view using spring physics.

| Parameter | Type | Description |
|-----------|------|-------------|
| `viewId` | `number` | The native view ID to animate. |
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

#### `keyframe(viewId, steps, config?)`

Run a multi-step keyframe animation on a view.

| Parameter | Type | Description |
|-----------|------|-------------|
| `viewId` | `number` | The native view ID to animate. |
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
| `viewId` | `number` | Target view ID. |
| `toStyles` | `Record<string, any>` | Target style properties. |
| `options` | `TimingConfig \| SpringConfig` | Animation configuration. |

### Convenience Methods

| Method | Description |
|--------|-------------|
| `fadeIn(viewId, duration?)` | Fade a view to opacity 1. Default duration: 300ms. |
| `fadeOut(viewId, duration?)` | Fade a view to opacity 0. Default duration: 300ms. |
| `slideInFromRight(viewId, duration?)` | Slide a view in from the right (translateX to 0). Default duration: 300ms. |
| `slideOutToRight(viewId, duration?)` | Slide a view out to the right (translateX to 400). Default duration: 300ms. |

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

const { timing, spring, keyframe, sequence, parallel, fadeIn, Easing } = useAnimation()
const boxRef = ref(null)

async function animateFadeIn() {
  const viewId = boxRef.value?.__nodeId
  if (!viewId) return
  await fadeIn(viewId, 500)
}

async function animateBounce() {
  const viewId = boxRef.value?.__nodeId
  if (!viewId) return
  await spring(viewId, { translateY: 0 }, { tension: 40, friction: 7 })
}

async function animateFlash() {
  const viewId = boxRef.value?.__nodeId
  if (!viewId) return
  await keyframe(viewId, [
    { offset: 0, opacity: 1 },
    { offset: 0.5, opacity: 0 },
    { offset: 1, opacity: 1 },
  ], { duration: 600 })
}

async function animateSequence() {
  const viewId = boxRef.value?.__nodeId
  if (!viewId) return
  await sequence([
    { type: 'timing', viewId, toStyles: { opacity: 0 }, options: { duration: 200 } },
    { type: 'timing', viewId, toStyles: { opacity: 1, translateX: 100 }, options: { duration: 300 } },
    { type: 'timing', viewId, toStyles: { translateX: 0 }, options: { duration: 300, easing: Easing.easeOut } },
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
    <VButton title="Fade In" :onPress="animateFadeIn" />
    <VButton title="Bounce" :onPress="animateBounce" />
    <VButton title="Flash" :onPress="animateFlash" />
    <VButton title="Sequence" :onPress="animateSequence" />
  </VView>
</template>
```

## Notes

- All animation functions return a `Promise` that resolves when the animation completes.
- The `viewId` parameter is the native node ID. Access it via the component ref's `__nodeId` property.
- `sequence` runs animations one after another; `parallel` runs them all at once. Both resolve when all animations finish.
- On Android, spring animations use `OvershootInterpolator` as an approximation of true spring physics.
- Durations and delays are specified in milliseconds in the JS API but converted to seconds internally on the native side.
