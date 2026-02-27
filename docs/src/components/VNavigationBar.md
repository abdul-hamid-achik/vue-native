# VNavigationBar

A navigation bar component for screen titles and back navigation. Renders a fixed-height bar at the top of the screen with a title, optional back button, and customizable colors.

## Usage

```vue
<VNavigationBar
  title="Settings"
  :showBack="true"
  @back="router.pop()"
/>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `title` | `string` | `''` | The title displayed in the center of the bar |
| `showBack` | `boolean` | `false` | Show a back button on the left side |
| `backTitle` | `string` | `'Back'` | Label for the back button |
| `backgroundColor` | `string` | `'#FFFFFF'` | Background color of the navigation bar |
| `tintColor` | `string` | `'#007AFF'` | Color of the back button text and icon |
| `titleColor` | `string` | `'#000000'` | Color of the title text |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@back` | -- | Fired when the back button is pressed |

## Example

```vue
<script setup>
import { useRouter } from '@thelacanians/vue-native-navigation'

const router = useRouter()
</script>

<template>
  <VView :style="{ flex: 1 }">
    <VNavigationBar
      title="Profile"
      :showBack="router.canGoBack.value"
      backTitle="Back"
      backgroundColor="#F8F8F8"
      tintColor="#007AFF"
      titleColor="#333333"
      @back="router.pop()"
    />
    <VView :style="{ flex: 1, padding: 16 }">
      <VText>Screen content goes here</VText>
    </VView>
  </VView>
</template>
```

## Notes

- `VNavigationBar` is exported from `@thelacanians/vue-native-navigation`, not the runtime package.
- The bar renders as a `VView` with a fixed height. It does not automatically account for the safe area — wrap it in a `VSafeArea` or add top padding on devices with notches.
- The back button only appears when `showBack` is `true`. Connect it to `router.pop()` or your own navigation logic.
