# Teleport

Teleport is a built-in component that allows you to render components outside their parent hierarchy. This is perfect for modals, dialogs, tooltips, overlays, and notifications.

## Basic Usage

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const showModal = ref(false)
</script>

<template>
  <VView :style="styles.container">
    <VButton title="Open Modal" @press="() => showModal = true" />
    
    <Teleport to="modal">
      <VModal v-if="showModal" @close="showModal = false">
        <VText :style="styles.title">Modal Title</VText>
        <VText :style="styles.content">This content is rendered in the modal container!</VText>
        <VButton title="Close" @press="() => showModal = false" />
      </VModal>
    </Teleport>
  </VView>
</template>

<script lang="ts">
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 16,
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 12,
  },
  content: {
    fontSize: 16,
    marginBottom: 20,
  },
})
</script>
```

## Available Targets

Vue Native provides these built-in teleport targets:

| Target | Description | Use Case |
|--------|-------------|----------|
| `modal` | Full-screen modal container | Dialogs, alerts, bottom sheets |
| `root` | App root view | Global overlays, debug panels |

## Programmatic Teleportation

For advanced use cases, you can teleport nodes programmatically:

```typescript
import { useTeleport, createNativeNode } from '@thelacanians/vue-native-runtime'

const { teleport } = useTeleport('modal')

// Create a node and teleport it
const node = createNativeNode('VView')
teleport(node)
```

## Common Patterns

### Modal Dialog

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const showConfirm = ref(false)
const confirmed = ref(false)
</script>

<template>
  <VView>
    <VButton title="Delete Item" @press="() => showConfirm = true" />
    
    <Teleport to="modal">
      <VModal v-if="showConfirm" @close="showConfirm = false">
        <VText>Are you sure you want to delete this item?</VText>
        <VView :style="{ flexDirection: 'row', gap: 12 }">
          <VButton 
            title="Cancel" 
            @press="() => showConfirm = false" 
          />
          <VButton 
            title="Delete" 
            variant="danger"
            @press="() => { confirmed = true; showConfirm = false }" 
          />
        </VView>
      </VModal>
    </Teleport>
  </VView>
</template>
```

### Toast Notification

```vue
<script setup>
import { ref, onMounted } from '@thelacanians/vue-native-runtime'

const toast = ref('')
const showToast = ref(false)

const showNotification = (message: string) => {
  toast.value = message
  showToast.value = true
  
  setTimeout(() => {
    showToast.value = false
  }, 3000)
}

defineExpose({ showNotification })
</script>

<template>
  <VView>
    <!-- Your content -->
    
    <Teleport to="root">
      <VView 
        v-if="showToast"
        :style="{
          position: 'absolute',
          bottom: 40,
          left: 20,
          right: 20,
          backgroundColor: '#333',
          padding: 16,
          borderRadius: 8,
        }"
      >
        <VText :style="{ color: '#fff', textAlign: 'center' }">
          {{ toast }}
        </VText>
      </VView>
    </Teleport>
  </VView>
</template>
```

### Bottom Sheet

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const showSheet = ref(false)
const options = ['Option 1', 'Option 2', 'Option 3']
</script>

<template>
  <VView>
    <VButton title="Show Options" @press="() => showSheet = true" />
    
    <Teleport to="modal">
      <VView 
        v-if="showSheet"
        :style="{
          position: 'absolute',
          bottom: 0,
          left: 0,
          right: 0,
          backgroundColor: '#fff',
          borderTopLeftRadius: 16,
          borderTopRightRadius: 16,
          padding: 20,
          maxHeight: 300,
        }"
      >
        <VText :style="{ fontSize: 18, fontWeight: 'bold', marginBottom: 16 }">
          Select an Option
        </VText>
        
        <VList 
          :data="options" 
          :renderItem="(item) => (
            <VButton 
              title={item} 
              onPress={() => { console.log(item); showSheet = false }} 
            />
          )" 
        />
        
        <VButton 
          title="Cancel" 
          variant="secondary"
          @press="() => showSheet = false" 
        />
      </VView>
    </Teleport>
  </VView>
</template>
```

## How It Works

Vue's core renderer resolves `<Teleport to="...">` through a `querySelector`
hook. The Vue Native renderer implements that hook to map a target name
(`'modal'` or `'root'`) to a cached, JS-only placeholder node -- it is never
announced to native and never appears in the native view hierarchy.

When Vue inserts the teleported children into that placeholder, the
renderer's `insert()` recognizes the placeholder and, instead of the normal
`appendChild` / `insertBefore` bridge calls, sends each child through
`NativeBridge.teleportTo(target, child.id)`. On the native side, `teleportTo`
resolves the target name to the real native container (the modal overlay
view for `'modal'`, the app's root view for `'root'`) and moves the child's
native view directly into it.

```
Vue Component Tree:               Native View Hierarchy:
┌────────────────────┐            ┌────────────────────┐
│ Parent View        │            │ Parent View        │
│  ├─ Button          │            │  ├─ Button          │
│  └─ Teleport        │            │                    │
│      to="modal"     │            │  Modal container   │
│      └─ VModal ─────┼──teleportTo─► └─ VModal view     │
└────────────────────┘            └────────────────────┘
     querySelector('modal') resolves the target name to a
     JS-only placeholder; insert() then calls teleportTo()
     for each child instead of the normal appendChild path.
```

Because children are moved with `teleportTo` one at a time as Vue inserts
them, **anchor/sibling order inside a teleport target is not preserved on the
native side** -- children land in the target container in whatever order
`insert()` calls `teleportTo`, not necessarily the order they appear in the
Vue template. If you teleport multiple sibling nodes into the same target and
care about stacking order, use `position: 'absolute'` with explicit offsets
(or z-index-like layering via mount order) rather than relying on document
order. Comment nodes and the empty text anchors Vue mounts alongside
teleported content are tracked in the JS-side tree only and are never sent to
native.

## Limitations

- Teleport targets must be registered in native code
- Teleported content is still part of the Vue component tree (reactivity works normally)
- Avoid teleporting to targets that may not exist (will silently fail)
- Currently only `modal` and `root` targets are available

## Troubleshooting

### Teleport content not showing

**Problem:** Content rendered with Teleport doesn't appear.

**Solutions:**
1. Verify the target exists (`modal` or `root`)
2. Check that the teleport container is being created (check native logs)
3. Ensure the teleported view has proper layout constraints (flex, width, height)
4. Make sure you're using `v-if` to conditionally render the content

### Teleport causes layout issues

**Problem:** Layout breaks when using Teleport.

**Solutions:**
1. Use `position: 'absolute'` for teleported overlays
2. Ensure the modal container has proper z-index
3. Check that the teleported view has explicit dimensions

### Memory leaks with Teleport

**Problem:** Memory usage grows over time.

**Solutions:**
1. Always use `v-if` to clean up teleported content when not needed
2. Remove event listeners in `onUnmounted`
3. Don't teleport large component trees unnecessarily

## API Reference

### `<Teleport>` Component

Re-exported from `@vue/runtime-core`.

**Props:**
- `to` (string, required): Target to teleport to

**Example:**
```vue
<Teleport to="modal">
  <VText>Teleported content</VText>
</Teleport>
```

### `useTeleport()` Composable

Programmatic teleportation API.

**Parameters:**
- `target` (string): Teleport target name

**Returns:**
- `teleport(node: NativeNode): void`: Function to teleport a node

**Example:**
```typescript
import { useTeleport } from '@thelacanians/vue-native-runtime'

const { teleport } = useTeleport('modal')
const node = createNativeNode('VView')
teleport(node)
```

## Native Implementation

Both native bridges implement `teleportTo(target, nodeId)` by resolving the
target name to a real, pre-existing container view and moving the child view
into it (`getTeleportTarget` is the switch that maps `'modal'` / `'root'` to
that container).

### iOS

From `NativeBridge.swift`:

```swift
private func getTeleportTarget(_ target: String) -> UIView? {
    switch target {
    case "root":
        return rootView
    case "modal":
        installModalContainerIfNeeded()
        return modalContainer
    default:
        return nil
    }
}

private func handleTeleportTo(args: [Any]) {
    // args: [target: String, nodeId: Int]
    guard let targetView = getTeleportTarget(target) else { return }
    guard let childView = viewRegistry[nodeId] else { return }
    childView.removeFromSuperview()
    targetView.addSubview(childView)
    // ...full-size Auto Layout constraints pin the child to targetView
}
```

### Android

From `NativeBridge.kt`:

```kotlin
private fun getTeleportTarget(target: String): ViewGroup? = when (target) {
    "root" -> rootView as? ViewGroup
    "modal" -> {
        if (modalContainer.parent == null && rootView != null) {
            (rootView as? ViewGroup)?.addView(modalContainer)
        }
        modalContainer
    }
    else -> null
}

private fun handleTeleportTo(args: JSONArray) {
    // args: [target: String, nodeId: Int]
    val targetView = getTeleportTarget(target) ?: return
    val childView = viewRegistry[nodeId] ?: return
    targetView.addView(childView)
}
```

::: tip Unrelated bridge op with a similar name
The bridge also has a `createTeleport` / `removeTeleport` pair that builds a
small container view tagged to a parent node. That op backs Vue's
`insertStaticContent` hook (used for hoisted static content), not the
`<Teleport>` component -- don't confuse it with the `teleportTo` mechanism
described above.
:::

## Related

- [VModal Component](../components/VModal.md)
- [Error Handling](./error-handling.md)
- [Performance](./performance.md)
