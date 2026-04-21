# VDrawer

Drawer navigation component (side menu). Slides in from the left or right edge of the screen with an optional overlay backdrop.

## Import

```ts
import { VDrawer } from '@thelacanians/vue-native-runtime'
```

## Usage

```vue
<script setup>
import { ref } from 'vue'
import { VDrawer, VPressable, VText } from '@thelacanians/vue-native-runtime'

const isOpen = ref(false)
</script>

<template>
  <VPressable @press="isOpen = true" :style="{ padding: 16 }">
    <VText>Open Menu</VText>
  </VPressable>

  <VDrawer v-model:open="isOpen" position="left">
    <template #header>
      <VText :style="{ fontSize: 20, fontWeight: 'bold' }">Menu</VText>
    </template>

    <VDrawer.Item icon="home" label="Home" @press="navigate('home')" />
    <VDrawer.Item icon="settings" label="Settings" @press="navigate('settings')" />
    <VDrawer.Item icon="profile" label="Profile" @press="navigate('profile')" />

    <template #footer>
      <VText :style="{ fontSize: 12, color: '#888' }">v1.0.0</VText>
    </template>
  </VDrawer>
</template>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `open` | `boolean` | `false` | Controls drawer visibility (use with `v-model:open`) |
| `position` | `'left' \| 'right'` | `'left'` | Which side the drawer slides in from |
| `width` | `number` | `280` | Width of the drawer panel in points |
| `overlayColor` | `string` | `'rgba(0,0,0,0.5)'` | Color of the backdrop overlay |
| `closeOnPressOutside` | `boolean` | `true` | Whether tapping the overlay closes the drawer |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `update:open` | `boolean` | Emitted when drawer visibility changes |
| `open` | — | Emitted when drawer finishes opening |
| `close` | — | Emitted when drawer finishes closing |

## Slots

| Slot | Description |
|------|-------------|
| `default` | Main drawer content (items, lists, etc.) |
| `header` | Content above the main items (logo, title, etc.) |
| `footer` | Content below the main items (version, logout, etc.) |

## VDrawer.Item

Individual menu items within the drawer.

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `icon` | `string` | — | Emoji or icon identifier |
| `label` | `string` | — | Display text |
| `active` | `boolean` | `false` | Whether this item is currently selected |
| `badge` | `string \| number` | — | Optional badge text/number |

### Events

| Event | Payload | Description |
|-------|---------|-------------|
| `press` | — | Emitted when the item is tapped |
