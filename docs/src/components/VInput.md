# VInput

Text input field. Maps to `UITextField` on iOS and `EditText` on Android.

## Usage

```vue
<script setup>
import { ref } from '@thelacanians/runtime'
const text = ref('')
</script>

<template>
  <VInput
    v-model="text"
    placeholder="Type something…"
    :style="{ borderWidth: 1, borderColor: '#ccc', borderRadius: 8, padding: 12 }"
  />
</template>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `modelValue` / `v-model` | `string` | `''` | Input value |
| `placeholder` | `string` | — | Placeholder text |
| `keyboardType` | `KeyboardType` | `'default'` | Keyboard type |
| `secureTextEntry` | `boolean` | `false` | Password field (hides text) |
| `autoCapitalize` | `'none'` \| `'sentences'` \| `'words'` \| `'characters'` | `'sentences'` | Auto-capitalization |
| `autoCorrect` | `boolean` | `true` | Auto-correction |
| `returnKeyType` | `'done'` \| `'go'` \| `'next'` \| `'search'` \| `'send'` | `'done'` | Return key label |
| `multiline` | `boolean` | `false` | Multi-line text input |
| `maxLength` | `number` | — | Maximum character count |
| `style` | `StyleProp` | — | Layout + appearance styles |

### `keyboardType` values

| Value | Description |
|-------|-------------|
| `'default'` | Standard keyboard |
| `'numeric'` | Number pad |
| `'email-address'` | Email keyboard |
| `'phone-pad'` | Phone dialer |
| `'decimal-pad'` | Decimal number pad |
| `'url'` | URL keyboard |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@update:modelValue` | `string` | Text changed |
| `@focus` | — | Input focused |
| `@blur` | — | Input unfocused |
| `@submit` | `string` | Return key pressed |
