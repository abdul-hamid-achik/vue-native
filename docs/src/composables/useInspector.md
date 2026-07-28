# useInspector

Introspect the live native view tree — useful for debugging layout and building devtools.
The tree is serialized by the native `Inspector` module, which walks its view registry.

## API

```ts
const { dumpTree } = useInspector()
```

| Method | Signature | Description |
|--------|-----------|-------------|
| `dumpTree` | `() => Promise<ViewTreeNode \| null>` | Dump the current native view tree (root node with nested children), or `null` on failure. |

### `ViewTreeNode`

```ts
interface ViewTreeNode {
  id: number                                    // native node id
  type: string                                  // e.g. "VView", "VText"
  props?: Record<string, unknown>               // props set on the node
  frame?: { x: number; y: number; width: number; height: number }
  children?: ViewTreeNode[]
}
```

## Example

```vue
<script setup lang="ts">
import { useInspector, VButton } from '@thelacanians/vue-native-runtime'

const { dumpTree } = useInspector()

async function logTree() {
  const tree = await dumpTree()
  console.log(JSON.stringify(tree, null, 2))
}
</script>

<template>
  <VButton title="Dump view tree" @press="logTree" />
</template>
```

## Notes

- The tree reflects the **native** view hierarchy (frames are in the parent's coordinate space).
- Returns `null` if the `Inspector` module is unavailable.
