# VSwitch

A boolean toggle switch. Maps to `UISwitch` on iOS and `SwitchCompat` on Android. Supports `v-model` for two-way binding.

## Usage

```vue
<VSwitch v-model="enabled" />
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `modelValue` | `boolean` | `false` | The current on/off state (use with `v-model`) |
| `disabled` | `boolean` | `false` | Disable user interaction |
| `onTintColor` | `string` | -- | Background color when the switch is on (hex string) |
| `thumbTintColor` | `string` | -- | Color of the thumb circle (hex string) |
| `style` | `Object` | -- | Layout styles |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@update:modelValue` | `boolean` | Emitted when toggled (used by `v-model`) |
| `@change` | `boolean` | Emitted when toggled with the new value |

## Example

```vue
<script setup>
import { ref } from 'vue'

const notifications = ref(true)
const darkMode = ref(false)
</script>

<template>
  <VView :style="styles.container">
    <VView :style="styles.row">
      <VText :style="styles.label">Notifications</VText>
      <VSwitch v-model="notifications" onTintColor="#34C759" />
    </VView>
    <VView :style="styles.row">
      <VText :style="styles.label">Dark Mode</VText>
      <VSwitch v-model="darkMode" onTintColor="#5856D6" />
    </VView>
  </VView>
</template>

<script>
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  container: {
    flex: 1,
    padding: 16,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  label: {
    fontSize: 16,
  },
})
</script>
```
