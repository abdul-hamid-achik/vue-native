# VAlertDialog

A native alert dialog component. Maps to `UIAlertController` (`.alert` style) on iOS and `AlertDialog.Builder` on Android.

VAlertDialog is a non-visual component -- it renders a zero-size hidden placeholder in the view tree and presents the native alert when `visible` becomes `true`.

## Usage

```vue
<VAlertDialog
  :visible="showAlert"
  title="Confirm"
  message="Are you sure you want to delete this item?"
  :buttons="[
    { label: 'Cancel', style: 'cancel' },
    { label: 'Delete', style: 'destructive' },
  ]"
  @cancel="showAlert = false"
  @action="onAction"
/>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `visible` | `boolean` | `false` | Show or hide the alert dialog |
| `title` | `string` | `''` | Alert title text |
| `message` | `string` | `''` | Alert message body |
| `buttons` | `AlertButton[]` | `[]` | Array of button configurations |

### AlertButton

```ts
interface AlertButton {
  label: string
  style?: 'default' | 'cancel' | 'destructive'
}
```

- `'default'` -- standard button appearance
- `'cancel'` -- cancel-style button (bold on iOS, triggers `@cancel` event)
- `'destructive'` -- red/destructive appearance

If no buttons are provided, a single "OK" button is shown by default.

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@confirm` | `{ label: string }` | Fired when a non-cancel button is pressed |
| `@cancel` | — | Fired when a cancel-style button is pressed |
| `@action` | `{ label: string }` | Fired when any non-cancel button is pressed (same as confirm) |

## Example

```vue
<script setup>
import { ref } from 'vue'

const showAlert = ref(false)
const result = ref('')

function handleAction(e) {
  result.value = `Pressed: ${e.label}`
  showAlert.value = false
}

function handleCancel() {
  result.value = 'Cancelled'
  showAlert.value = false
}
</script>

<template>
  <VView :style="styles.container">
    <VButton :style="styles.button" :onPress="() => showAlert = true">
      <VText :style="styles.buttonText">Show Alert</VText>
    </VButton>

    <VText v-if="result" :style="styles.result">{{ result }}</VText>

    <VAlertDialog
      :visible="showAlert"
      title="Delete Item"
      message="This action cannot be undone."
      :buttons="[
        { label: 'Cancel', style: 'cancel' },
        { label: 'Delete', style: 'destructive' },
      ]"
      @action="handleAction"
      @cancel="handleCancel"
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
    gap: 16,
  },
  button: {
    backgroundColor: '#FF3B30',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  result: {
    fontSize: 14,
    color: '#666',
  },
})
</script>
```

## Notes

- Set `visible` back to `false` in your event handlers to dismiss the dialog. The native alert closes automatically when a button is pressed, but the `visible` state should be reset to allow re-presenting.
- The `@confirm` and `@action` events both fire for non-cancel buttons. Use whichever suits your needs -- `@action` includes the button label in its payload.
