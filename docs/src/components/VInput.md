# VInput

Text input field. Maps to `UITextField` (single-line) or `UITextView` (multiline) on iOS, and `EditText` on Android. Supports `v-model` for two-way binding.

## Usage

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'
const text = ref('')
</script>

<template>
  <VInput
    v-model="text"
    placeholder="Type something..."
    :style="{ borderWidth: 1, borderColor: '#ccc', borderRadius: 8, padding: 12 }"
  />
</template>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `modelValue` / `v-model` | `string` | `''` | Input value |
| `placeholder` | `string` | -- | Placeholder text |
| `keyboardType` | `KeyboardType` | `'default'` | Keyboard type |
| `secureTextEntry` | `boolean` | `false` | Password field (hides text) |
| `autoCapitalize` | `'none'` \| `'sentences'` \| `'words'` \| `'characters'` | `'sentences'` | Auto-capitalization |
| `autoCorrect` | `boolean` | `true` | Auto-correction |
| `returnKeyType` | `'done'` \| `'go'` \| `'next'` \| `'search'` \| `'send'` | `'done'` | Return key label |
| `multiline` | `boolean` | `false` | Multi-line text input (uses UITextView on iOS) |
| `maxLength` | `number` | -- | Maximum character count |
| `style` | `StyleProp` | -- | Layout + appearance styles |
| `accessibilityLabel` | `string` | -- | Accessible description |
| `accessibilityRole` | `string` | -- | Accessibility role |
| `accessibilityHint` | `string` | -- | Additional accessibility context |
| `accessibilityState` | `object` | -- | Accessibility state |

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
| `@update:modelValue` | `string` | Text changed (used by `v-model`) |
| `@focus` | -- | Input focused |
| `@blur` | -- | Input unfocused |
| `@submit` | `string` | Return key pressed |

## Example

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const username = ref('')
const password = ref('')
const bio = ref('')
</script>

<template>
  <VView :style="styles.container">
    <VInput
      v-model="username"
      placeholder="Username"
      autoCapitalize="none"
      autoCorrect="false"
      :style="styles.input"
      @submit="() => {}"
    />

    <VInput
      v-model="password"
      placeholder="Password"
      :secureTextEntry="true"
      returnKeyType="done"
      :style="styles.input"
    />

    <VInput
      v-model="bio"
      placeholder="Tell us about yourself..."
      :multiline="true"
      :maxLength="200"
      :style="[styles.input, { height: 100 }]"
    />
  </VView>
</template>

<script>
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  container: {
    flex: 1,
    padding: 20,
    gap: 12,
  },
  input: {
    borderWidth: 1,
    borderColor: '#ccc',
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
  },
})
</script>
```
