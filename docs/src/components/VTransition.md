# VTransition & VTransitionGroup

Animate elements when they enter or leave the DOM. Similar to Vue's `<Transition>` but uses native animations instead of CSS.

## Overview

Vue Native provides two transition components:

- **`<VTransition>`** - Animate a single element entering/leaving
- **`<VTransitionGroup>`** - Animate multiple elements in a list

Both use the `useAnimation` composable under the hood to drive platform-native animations on iOS, Android, and macOS.

## VTransition

### Basic Usage

```vue
<script setup>
import { ref } from 'vue'
import { VTransition, VView, VText, VButton } from '@thelacanians/vue-native-runtime'

const show = ref(false)
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VButton title="Toggle" :onPress="() => show = !show" />
    
    <VTransition :show="show" :duration="300" name="fade">
      <VView :style="{ padding: 20, backgroundColor: '#007AFF' }">
        <VText :style="{ color: '#fff' }">Hello, World!</VText>
      </VView>
    </VTransition>
  </VView>
</template>
```

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `show` | `boolean` | `true` | Controls whether the element is visible |
| `name` | `string` | `'default'` | Transition name for referencing in styles |
| `duration` | `number` | `300` | Animation duration in milliseconds |
| `enterFrom` | `StyleProp` | -- | Initial style when entering |
| `enterTo` | `StyleProp` | -- | Target style after entering |
| `leaveFrom` | `StyleProp` | -- | Initial style when leaving |
| `leaveTo` | `StyleProp` | -- | Target style after leaving |
| `easing` | `string` | `'ease'` | Animation easing function |

### Built-in Transitions

#### Fade

```vue
<VTransition :show="show" name="fade" :duration="200">
  <VView><VText>Fading content</VText></VView>
</VTransition>
```

Equivalent to:

```vue
<VTransition 
  :show="show"
  :enterFrom="{ opacity: 0 }"
  :enterTo="{ opacity: 1 }"
  :leaveFrom="{ opacity: 1 }"
  :leaveTo="{ opacity: 0 }"
  :duration="200"
>
  <VView><VText>Fading content</VText></VView>
</VTransition>
```

#### Slide

```vue
<VTransition :show="show" name="slide" :duration="300">
  <VView><VText>Sliding content</VText></VView>
</VTransition>
```

Slides in from the left and out to the left.

### Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@before-enter` | -- | Called before enter animation starts |
| `@enter` | -- | Called when enter animation starts |
| `@after-enter` | -- | Called when enter animation completes |
| `@before-leave` | -- | Called before leave animation starts |
| `@leave` | -- | Called when leave animation starts |
| `@after-leave` | -- | Called when leave animation completes |

### Example: Custom Transition

```vue
<script setup>
import { ref } from 'vue'
import { VTransition, VView, VText, VButton } from '@thelacanians/vue-native-runtime'

const show = ref(false)
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VButton title="Toggle" :onPress="() => show = !show" />
    
    <VTransition
      :show="show"
      :duration="400"
      :enterFrom="{ opacity: 0, translateY: 50, scaleX: 0.8, scaleY: 0.8 }"
      :enterTo="{ opacity: 1, translateY: 0, scaleX: 1, scaleY: 1 }"
      :leaveFrom="{ opacity: 1, translateY: 0 }"
      :leaveTo="{ opacity: 0, translateY: -50 }"
      easing="easeInOut"
    >
      <VView :style="{ padding: 20, backgroundColor: '#34C759', borderRadius: 12 }">
        <VText :style="{ color: '#fff', fontSize: 18 }">Animated Card</VText>
      </VView>
    </VTransition>
  </VView>
</template>
```

## VTransitionGroup

Animate multiple keyed elements as they're added or removed.

### Basic Usage

```vue
<script setup>
import { ref } from 'vue'
import { VTransitionGroup, VView, VText, VButton } from '@thelacanians/vue-native-runtime'

const items = ref([
  { id: 1, text: 'First' },
  { id: 2, text: 'Second' },
  { id: 3, text: 'Third' },
])

function addItem() {
  items.value.push({ id: Date.now(), text: `Item ${items.value.length + 1}` })
}

function removeItem(id) {
  items.value = items.value.filter(item => item.id !== id)
}
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VButton title="Add Item" :onPress="addItem" />
    
    <VTransitionGroup :duration="300" name="list">
      <VView 
        v-for="item in items" 
        :key="item.id"
        :style="{ padding: 12, backgroundColor: '#f0f0f0', marginBottom: 8, flexDirection: 'row', justifyContent: 'space-between' }"
      >
        <VText>{{ item.text }}</VText>
        <VButton title="Remove" :onPress="() => removeItem(item.id)" />
      </VView>
    </VTransitionGroup>
  </VView>
</template>
```

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `tag` | `string` | `'VView'` | Native container element to render |
| `duration` | `number` | `300` | Animation duration in milliseconds |
| `name` | `string` | `'v'` | Transition name passed to Vue's transition hooks |
| `appear` | `boolean` | `false` | Animate items on initial mount |
| `persist` | `boolean` | `false` | Keep leaving items mounted while the leave hook runs |
| `moveClass` | `string` | `''` | Reserved for future move-animation support |

### Reordering Lists

Items should be keyed so Vue can track additions and removals correctly. Reordering is supported by Vue's keyed diffing, but Vue Native does not yet run FLIP-style move animations for reordered items.

```vue
<script setup>
import { ref } from 'vue'
import { VTransitionGroup, VView, VText, VButton } from '@thelacanians/vue-native-runtime'

const items = ref(['Apple', 'Banana', 'Cherry', 'Date'])

function shuffle() {
  items.value = items.value.sort(() => Math.random() - 0.5)
}
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VButton title="Shuffle" :onPress="shuffle" />
    
    <VTransitionGroup :duration="250">
      <VView 
        v-for="(item, index) in items" 
        :key="item"
        :style="{ padding: 8 }"
      >
        <VText>{{ index + 1 }}. {{ item }}</VText>
      </VView>
    </VTransitionGroup>
  </VView>
</template>
```

## Platform Notes

### iOS

Uses UIKit's `UIView.animate` via the Animation module.

### Android

Uses Android's `ValueAnimator` via the Animation module.

### macOS

Uses AppKit's `NSView.animate` via the Animation module.

## See Also

- [useAnimation](../composables/useAnimation.md) - Low-level animation API
- [KeepAlive](./KeepAlive.md) - Cache component instances
- [VSuspense](./VSuspense.md) - Handle async components
