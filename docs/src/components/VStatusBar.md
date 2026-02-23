# VStatusBar

Controls the appearance of the system status bar. Maps to status bar style changes via the root view controller on iOS and `WindowInsetsController` on Android.

VStatusBar is a non-visual component -- it renders nothing on screen but configures the system status bar when mounted or when its props change.

## Usage

```vue
<VStatusBar barStyle="light-content" />
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `barStyle` | `'default' \| 'light-content' \| 'dark-content'` | `'default'` | Status bar text/icon color scheme |
| `hidden` | `boolean` | `false` | Hide the status bar entirely |
| `animated` | `boolean` | `true` | Animate style and visibility changes |

### Bar Styles

- `'default'` -- system default (typically dark text on light backgrounds)
- `'light-content'` -- white text and icons (use on dark backgrounds)
- `'dark-content'` -- dark text and icons (use on light backgrounds)

## Events

VStatusBar does not emit any events.

## Example

```vue
<script setup>
import { ref } from 'vue'

const isDarkMode = ref(false)
</script>

<template>
  <VView :style="isDarkMode ? styles.dark : styles.light">
    <VStatusBar :barStyle="isDarkMode ? 'light-content' : 'dark-content'" />

    <VSwitch :value="isDarkMode" @change="isDarkMode = $event.value" />
    <VText :style="isDarkMode ? styles.lightText : styles.darkText">
      Dark mode: {{ isDarkMode ? 'ON' : 'OFF' }}
    </VText>
  </VView>
</template>

<script>
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  light: {
    flex: 1,
    backgroundColor: '#fff',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 16,
  },
  dark: {
    flex: 1,
    backgroundColor: '#1c1c1e',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 16,
  },
  lightText: {
    color: '#fff',
    fontSize: 16,
  },
  darkText: {
    color: '#000',
    fontSize: 16,
  },
})
</script>
```

## Notes

- On iOS, `VStatusBar` posts notifications that the root `VueNativeViewController` observes to update `preferredStatusBarStyle` and `prefersStatusBarHidden`.
- Place `VStatusBar` anywhere in your component tree -- it does not need to be at the root. Only one `VStatusBar` should be active at a time; if multiple are rendered, the last one to update wins.
