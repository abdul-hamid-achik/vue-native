# VPicker

A date and time picker component. Maps to `UIDatePicker` on iOS and `DatePicker` on Android.

## Usage

```vue
<VPicker mode="date" :value="selectedDate" @change="selectedDate = $event.value" />
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `mode` | `'date' \| 'time' \| 'datetime'` | `'date'` | Picker mode |
| `value` | `number` | — | Selected date/time as epoch milliseconds |
| `minimumDate` | `number` | — | Earliest selectable date (epoch ms) |
| `maximumDate` | `number` | — | Latest selectable date (epoch ms) |
| `minuteInterval` | `number` | `1` | Interval between selectable minutes (e.g. `15` for quarter-hour steps) |
| `style` | `StyleProp` | — | Layout + appearance styles |

### Modes

- `'date'` -- date-only picker (year, month, day)
- `'time'` -- time-only picker (hours, minutes)
- `'datetime'` -- combined date and time picker

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@change` | `{ value: number }` | Fired when the user selects a new date/time. `value` is epoch milliseconds. |

## Example

```vue
<script setup>
import { ref, computed } from 'vue'

const selectedDate = ref(Date.now())

const formatted = computed(() => {
  return new Date(selectedDate.value).toLocaleDateString()
})

function handleChange(e) {
  selectedDate.value = e.value
}
</script>

<template>
  <VView :style="styles.container">
    <VText :style="styles.label">Selected: {{ formatted }}</VText>

    <VPicker
      mode="date"
      :value="selectedDate"
      :minimumDate="Date.now() - 365 * 24 * 60 * 60 * 1000"
      :maximumDate="Date.now() + 365 * 24 * 60 * 60 * 1000"
      @change="handleChange"
    />
  </VView>
</template>

<script>
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: 20,
    padding: 24,
  },
  label: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
  },
})
</script>
```

### Time picker with 15-minute intervals

```vue
<script setup>
import { ref } from 'vue'

const selectedTime = ref(Date.now())
</script>

<template>
  <VPicker
    mode="time"
    :value="selectedTime"
    :minuteInterval="15"
    @change="selectedTime = $event.value"
  />
</template>
```

## Notes

- All date/time values are in epoch milliseconds (JavaScript `Date.now()` format). Convert with `new Date(value)` for display.
- On iOS, the picker uses the compact style (`UIDatePicker.preferredDatePickerStyle = .compact`) on iOS 14+.
- The `minuteInterval` must be a divisor of 60 (e.g. 1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30).
