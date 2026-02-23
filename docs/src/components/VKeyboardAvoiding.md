# VKeyboardAvoiding

A container that adjusts its bottom padding when the software keyboard appears, preventing content from being obscured. Maps to a custom `KeyboardAvoidingView` (UIView subclass) on iOS and a `FlexboxLayout` on Android.

## Usage

```vue
<template>
  <VKeyboardAvoiding :style="{ flex: 1 }">
    <VInput placeholder="Type here..." />
    <VButton @press="submit">
      <VText>Send</VText>
    </VButton>
  </VKeyboardAvoiding>
</template>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `style` | `Object` | -- | Layout + appearance styles |
| `testID` | `string` | -- | Test identifier for end-to-end testing |

## Example

```vue
<script setup>
import { ref } from 'vue'

const message = ref('')
const send = () => {
  console.log('Sending:', message.value)
  message.value = ''
}
</script>

<template>
  <VSafeArea :style="styles.safe">
    <VKeyboardAvoiding :style="styles.container">
      <VView :style="styles.messages">
        <VText>Chat messages go here</VText>
      </VView>
      <VView :style="styles.inputRow">
        <VInput
          v-model="message"
          placeholder="Type a message..."
          :style="styles.input"
        />
        <VButton :style="styles.sendBtn" @press="send">
          <VText :style="styles.sendLabel">Send</VText>
        </VButton>
      </VView>
    </VKeyboardAvoiding>
  </VSafeArea>
</template>

<script>
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  safe: {
    flex: 1,
  },
  container: {
    flex: 1,
  },
  messages: {
    flex: 1,
    padding: 16,
  },
  inputRow: {
    flexDirection: 'row',
    padding: 8,
    borderTopWidth: 1,
    borderTopColor: '#e0e0e0',
  },
  input: {
    flex: 1,
    borderWidth: 1,
    borderColor: '#ccc',
    borderRadius: 20,
    paddingHorizontal: 16,
    paddingVertical: 8,
  },
  sendBtn: {
    marginLeft: 8,
    backgroundColor: '#007AFF',
    borderRadius: 20,
    paddingHorizontal: 16,
    justifyContent: 'center',
  },
  sendLabel: {
    color: '#fff',
    fontWeight: '600',
  },
})
</script>
```

## How It Works

On iOS, the view observes `keyboardWillShowNotification` and `keyboardWillHideNotification`. When the keyboard appears, it sets Yoga bottom padding to the keyboard height and triggers a layout pass. When the keyboard hides, bottom padding resets to 0.

On Android, keyboard avoidance is handled by the system when the Activity uses `android:windowSoftInputMode="adjustResize"` (the default for Vue Native apps), so the component acts as a standard flex container.

::: tip
Place `VKeyboardAvoiding` as a wrapper around any screen that contains text inputs. Pair it with `VSafeArea` for full-screen forms.
:::
