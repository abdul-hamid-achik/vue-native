# VActionSheet

A native action sheet component that slides up from the bottom of the screen. Maps to `UIAlertController` (`.actionSheet` style) on iOS and an `AlertDialog` with an item list on Android.

VActionSheet is a non-visual component -- it renders a zero-size hidden placeholder and presents the native sheet when `visible` becomes `true`.

## Usage

```vue
<VActionSheet
  :visible="showSheet"
  title="Choose an option"
  :actions="[
    { label: 'Edit' },
    { label: 'Share' },
    { label: 'Delete', style: 'destructive' },
    { label: 'Cancel', style: 'cancel' },
  ]"
  @action="onAction"
  @cancel="showSheet = false"
/>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `visible` | `boolean` | `false` | Show or hide the action sheet |
| `title` | `string` | — | Optional title displayed at the top |
| `message` | `string` | — | Optional message displayed below the title |
| `actions` | `ActionSheetAction[]` | `[]` | Array of action configurations |

### ActionSheetAction

```ts
interface ActionSheetAction {
  label: string
  style?: 'default' | 'cancel' | 'destructive'
}
```

- `'default'` -- standard action appearance
- `'cancel'` -- cancel action (separated on iOS, triggers `@cancel` event)
- `'destructive'` -- red/destructive appearance

If no action has `style: 'cancel'`, a "Cancel" button is automatically added.

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@action` | `{ label: string }` | Fired when a non-cancel action is pressed |
| `@cancel` | — | Fired when the cancel action is pressed |

## Example

```vue
<script setup>
import { ref } from 'vue'

const showSheet = ref(false)
const lastAction = ref('')

function handleAction(e) {
  lastAction.value = e.label
  showSheet.value = false
}
</script>

<template>
  <VView :style="styles.container">
    <VButton :style="styles.button" @press="showSheet = true">
      <VText :style="styles.buttonText">Show Options</VText>
    </VButton>

    <VText v-if="lastAction" :style="styles.result">
      Selected: {{ lastAction }}
    </VText>

    <VActionSheet
      :visible="showSheet"
      title="Photo Options"
      message="What would you like to do with this photo?"
      :actions="[
        { label: 'Save to Library' },
        { label: 'Copy Link' },
        { label: 'Delete Photo', style: 'destructive' },
        { label: 'Cancel', style: 'cancel' },
      ]"
      @action="handleAction"
      @cancel="showSheet = false"
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
    backgroundColor: '#007AFF',
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

- On iPad, the action sheet is presented as a popover centered on the screen.
- Reset `visible` to `false` in your event handlers to keep state in sync with the native presentation.
