# VRadio

A radio button group for single-selection from a list of options. Maps to a custom `UIStackView` with radio circles on iOS and `RadioGroup` + `RadioButton` on Android.

Supports `v-model` for two-way binding of the selected value.

## Usage

```vue
<VRadio
  v-model="selectedSize"
  :options="[
    { label: 'Small', value: 'sm' },
    { label: 'Medium', value: 'md' },
    { label: 'Large', value: 'lg' },
  ]"
  tintColor="#007AFF"
/>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `modelValue` | `String` | -- | The currently selected value. Bind with `v-model` |
| `options` | `RadioOption[]` | **(required)** | Array of `{ label: string; value: string }` objects |
| `disabled` | `Boolean` | `false` | Disables all radio buttons when `true` |
| `tintColor` | `String` | -- | Color of the selected radio circle |
| `style` | `Object` | -- | Layout + appearance styles for the outer container |
| `accessibilityLabel` | `String` | -- | Accessibility label for the radio group |

### RadioOption

```ts
interface RadioOption {
  label: string
  value: string
}
```

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `update:modelValue` | `string` | Emitted when the selection changes. Used internally by `v-model` |
| `change` | `string` | Emitted when the user selects a different option |

## Example

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const priority = ref('medium')

const priorityOptions = [
  { label: 'Low', value: 'low' },
  { label: 'Medium', value: 'medium' },
  { label: 'High', value: 'high' },
  { label: 'Critical', value: 'critical' },
]

function onPriorityChange(value) {
  console.log('Priority set to:', value)
}
</script>

<template>
  <VView :style="{ padding: 24, gap: 20 }">
    <VText :style="{ fontSize: 20, fontWeight: '700' }">Task Priority</VText>

    <VRadio
      v-model="priority"
      :options="priorityOptions"
      tintColor="#FF3B30"
      @change="onPriorityChange"
    />

    <VView
      :style="{
        backgroundColor: '#f0f0f0',
        padding: 12,
        borderRadius: 8,
        marginTop: 8,
      }"
    >
      <VText :style="{ color: '#666' }">
        Selected: {{ priority }}
      </VText>
    </VView>
  </VView>
</template>
```
