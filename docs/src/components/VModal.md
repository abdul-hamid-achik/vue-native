# VModal

A window-level modal overlay component. Renders its children in a full-screen overlay above all other content. Maps to a key-window overlay `UIView` on iOS and a `Dialog` on Android.

## Usage

```vue
<VModal :visible="showModal" @dismiss="showModal = false">
  <VView :style="styles.content">
    <VText>Hello from the modal!</VText>
  </VView>
</VModal>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `visible` | `boolean` | `false` | Show or hide the modal overlay |
| `style` | `StyleProp` | — | Style applied to the overlay container |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@dismiss` | — | Fired when the modal requests dismissal (e.g. backdrop tap) |

## Slots

| Slot | Description |
|------|-------------|
| `default` | Content rendered inside the modal overlay |

## Example

```vue
<script setup>
import { ref } from 'vue'

const showModal = ref(false)
</script>

<template>
  <VView :style="styles.container">
    <VButton :style="styles.openButton" :onPress="() => showModal = true">
      <VText :style="styles.buttonText">Open Modal</VText>
    </VButton>

    <VModal :visible="showModal" @dismiss="showModal = false">
      <VView :style="styles.modalContent">
        <VText :style="styles.title">Modal Title</VText>
        <VText :style="styles.body">
          This content is rendered in a full-screen overlay above all other views.
        </VText>
        <VButton :style="styles.closeButton" :onPress="() => showModal = false">
          <VText :style="styles.buttonText">Close</VText>
        </VButton>
      </VView>
    </VModal>
  </VView>
</template>

<script>
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  openButton: {
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
  modalContent: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
    gap: 16,
  },
  title: {
    fontSize: 22,
    fontWeight: '700',
    color: '#fff',
  },
  body: {
    fontSize: 16,
    color: '#eee',
    textAlign: 'center',
  },
  closeButton: {
    backgroundColor: '#fff',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
})
</script>
```

## Notes

- The overlay has a semi-transparent black background (`rgba(0, 0, 0, 0.5)`) by default on iOS.
- Children of `VModal` are rendered inside the overlay, not in the regular view tree. This means the modal content appears above all other views including navigation bars.
- The VModal placeholder itself is a hidden, zero-size view in the layout tree -- it does not affect the layout of sibling components.
