# VSegmentedControl

A horizontal segmented control (tab strip) for selecting one option from a set. Maps to `UISegmentedControl` on iOS and a `RadioGroup` with `RadioButton` items on Android.

## Usage

```vue
<VSegmentedControl
  :values="['Day', 'Week', 'Month']"
  :selectedIndex="0"
  @change="onSegmentChange"
/>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `values` | `string[]` | **(required)** | The labels for each segment |
| `selectedIndex` | `number` | `0` | Index of the currently selected segment |
| `tintColor` | `string` | -- | Tint color for the selected segment (hex string) |
| `enabled` | `boolean` | `true` | Whether the control is interactive |
| `style` | `Object` | `{}` | Layout styles |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@change` | `{ selectedIndex: number, value: string }` | Emitted when the user selects a different segment |

## Example

```vue
<script setup>
import { ref } from 'vue'

const viewMode = ref(0)
const modes = ['List', 'Grid', 'Map']

const onModeChange = (e) => {
  viewMode.value = e.selectedIndex
}
</script>

<template>
  <VView :style="styles.container">
    <VSegmentedControl
      :values="modes"
      :selectedIndex="viewMode"
      tintColor="#007AFF"
      :style="styles.segment"
      @change="onModeChange"
    />
    <VText :style="styles.label">Selected: {{ modes[viewMode] }}</VText>
  </VView>
</template>

<script>
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  container: {
    flex: 1,
    padding: 24,
  },
  segment: {
    marginBottom: 16,
  },
  label: {
    fontSize: 16,
    color: '#666',
  },
})
</script>
```

::: tip
`VSegmentedControl` does not support `v-model`. Use the `@change` event to update your selected index manually as shown above.
:::
