# useTeleport

Programmatically teleport native view nodes to different containers (e.g., modal overlay, root view). This is the composable API for the `<Teleport>` component.

## Import

```ts
import { useTeleport } from '@thelacanians/vue-native-runtime'
```

## Usage

```ts
import { useTeleport, createNativeNode } from '@thelacanians/vue-native-runtime'

const { teleport } = useTeleport('modal')

// Create a view and teleport it to the modal container
const node = createNativeNode('VView')
teleport(node)
```

## API

```ts
function useTeleport(target: string): {
  teleport: (node: NativeNode) => void
}
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `target` | `string` | Teleport target name. Built-in targets: `'modal'`, `'root'` |

### Returns

| Property | Type | Description |
|----------|------|-------------|
| `teleport` | `(node: NativeNode) => void` | Function that moves the given node to the target container |

## Teleport Targets

| Target | Description |
|--------|-------------|
| `'root'` | The root view of the app (top of the view hierarchy) |
| `'modal'` | A dedicated modal container that overlays the root view |

## Example: Custom Modal

```vue
<script setup>
import { ref } from 'vue'
import { useTeleport, createNativeNode } from '@thelacanians/vue-native-runtime'

const { teleport } = useTeleport('modal')
const showModal = ref(false)

function openModal() {
  showModal.value = true
}
</script>

<template>
  <Teleport to="modal" v-if="showModal">
    <VView :style="{ flex: 1, justifyContent: 'center', alignItems: 'center' }">
      <VText>Modal Content</VText>
      <VButton label="Close" @press="showModal = false" />
    </VView>
  </Teleport>
</template>
```

## Notes

- Teleported nodes are moved (not copied) — they are removed from their original parent
- The `Teleport` component (Vue built-in) uses this mechanism under the hood
- Teleport markers create native containers that are cleaned up when the teleport is removed
