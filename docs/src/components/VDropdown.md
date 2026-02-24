# VDropdown

A dropdown picker for selecting a single value from a list of options. Maps to `UIMenu` (iOS 14+) or `UIPickerView` on iOS and `Spinner` on Android.

Supports `v-model` for two-way binding of the selected value.

## Usage

```vue
<VDropdown
  v-model="selectedCountry"
  :options="[
    { label: 'United States', value: 'us' },
    { label: 'Canada', value: 'ca' },
    { label: 'Mexico', value: 'mx' },
  ]"
  placeholder="Choose a country"
/>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `modelValue` | `String` | -- | The currently selected value. Bind with `v-model` |
| `options` | `DropdownOption[]` | **(required)** | Array of `{ label: string; value: string }` objects |
| `placeholder` | `String` | `'Select...'` | Placeholder text shown when no value is selected |
| `disabled` | `Boolean` | `false` | Disables interaction when `true` |
| `tintColor` | `String` | -- | Accent color for the dropdown control |
| `style` | `Object` | -- | Layout + appearance styles |
| `accessibilityLabel` | `String` | -- | Accessibility label read by screen readers |

### DropdownOption

```ts
interface DropdownOption {
  label: string
  value: string
}
```

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `update:modelValue` | `string` | Emitted when the selection changes. Used internally by `v-model` |
| `change` | `string` | Emitted when the user picks a different option |

## Example

```vue
<script setup>
import { ref, computed } from '@thelacanians/vue-native-runtime'

const language = ref('')
const theme = ref('system')

const languages = [
  { label: 'English', value: 'en' },
  { label: 'Spanish', value: 'es' },
  { label: 'French', value: 'fr' },
  { label: 'German', value: 'de' },
  { label: 'Japanese', value: 'ja' },
]

const themes = [
  { label: 'System Default', value: 'system' },
  { label: 'Light', value: 'light' },
  { label: 'Dark', value: 'dark' },
]

const summary = computed(() => {
  const lang = languages.find((l) => l.value === language.value)
  return lang ? lang.label : 'None'
})
</script>

<template>
  <VView :style="{ padding: 24, gap: 20 }">
    <VText :style="{ fontSize: 20, fontWeight: '700' }">Preferences</VText>

    <VView :style="{ gap: 6 }">
      <VText :style="{ fontSize: 14, color: '#666' }">Language</VText>
      <VDropdown
        v-model="language"
        :options="languages"
        placeholder="Choose a language"
        tintColor="#007AFF"
      />
    </VView>

    <VView :style="{ gap: 6 }">
      <VText :style="{ fontSize: 14, color: '#666' }">Theme</VText>
      <VDropdown
        v-model="theme"
        :options="themes"
        tintColor="#5856D6"
      />
    </VView>

    <VView
      :style="{
        backgroundColor: '#f0f0f0',
        padding: 12,
        borderRadius: 8,
        marginTop: 8,
      }"
    >
      <VText :style="{ color: '#666' }">
        Language: {{ summary }} | Theme: {{ theme }}
      </VText>
    </VView>
  </VView>
</template>
```
