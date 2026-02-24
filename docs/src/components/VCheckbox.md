# VCheckbox

A toggle checkbox control. Maps to a custom checkbox view on iOS and `CheckBox` on Android.

Supports `v-model` for two-way binding of the checked state.

## Usage

```vue
<VCheckbox
  v-model="agreed"
  label="I agree to the terms"
  checkColor="#fff"
  tintColor="#007AFF"
/>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `modelValue` | `Boolean` | `false` | Whether the checkbox is checked. Bind with `v-model` |
| `disabled` | `Boolean` | `false` | Disables interaction when `true` |
| `label` | `String` | -- | Text label displayed next to the checkbox |
| `checkColor` | `String` | -- | Color of the checkmark icon |
| `tintColor` | `String` | -- | Color of the checkbox border and fill when checked |
| `style` | `Object` | -- | Layout + appearance styles |
| `accessibilityLabel` | `String` | -- | Accessibility label read by screen readers |
| `accessibilityHint` | `String` | -- | Additional accessibility hint describing the result of the action |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `update:modelValue` | `boolean` | Emitted when the checked state changes. Used internally by `v-model` |
| `change` | `boolean` | Emitted when the user toggles the checkbox |

## Example

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const notifications = ref(true)
const darkMode = ref(false)
const agreed = ref(false)

function onAgreedChange(value) {
  console.log('Agreement changed:', value)
}
</script>

<template>
  <VView :style="{ padding: 24, gap: 16 }">
    <VText :style="{ fontSize: 20, fontWeight: '700' }">Settings</VText>

    <VCheckbox
      v-model="notifications"
      label="Enable notifications"
      tintColor="#007AFF"
      checkColor="#fff"
    />

    <VCheckbox
      v-model="darkMode"
      label="Dark mode"
      tintColor="#34C759"
      checkColor="#fff"
    />

    <VCheckbox
      v-model="agreed"
      label="I agree to the terms and conditions"
      tintColor="#FF9500"
      checkColor="#fff"
      @change="onAgreedChange"
    />

    <VButton
      :disabled="!agreed"
      :style="{
        backgroundColor: agreed ? '#007AFF' : '#ccc',
        padding: 14,
        borderRadius: 8,
        marginTop: 12,
      }"
      :onPress="() => console.log('Submitted')"
    >
      <VText :style="{ color: '#fff', fontWeight: '600', textAlign: 'center' }">
        Submit
      </VText>
    </VButton>
  </VView>
</template>
```
