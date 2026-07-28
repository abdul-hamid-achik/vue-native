# Custom Native Components (escape hatch)

Vue Native ships a rich set of built-in components, but sometimes you need to embed an
arbitrary native view — a map, a custom player, a third-party widget. The escape hatch lets
you register a native component factory on the host and render it from Vue with
`createNativeComponent`.

## 1. Register a factory on the native host

Implement a component factory (the same `NativeComponentFactory` / `ComponentFactory`
interface the built-in components use) and register it under a name.

::: code-group

```swift [iOS]
// In your app target, before the VueNativeViewController loads:
VueNativeViewController.registerComponent("MapGL", factory: MapGLFactory())
```

```kotlin [Android]
// In your Application/Activity, before the VueNativeActivity loads:
VueNativeActivity.registerComponent("MapGL", MapGLFactory())
```

```swift [macOS]
VueNativeWindowController.registerComponent("MapGL", factory: MapGLFactory())
```

:::

Your factory creates the native view, applies props in `updateProp`, and forwards events —
exactly like a built-in factory.

## 2. Render it from Vue

```ts
import { createNativeComponent } from '@thelacanians/vue-native-runtime'

// Creates a component that renders the native "MapGL" element.
const VMapGL = createNativeComponent('MapGL')
```

```vue
<template>
  <VMapGL
    :style="{ flex: 1 }"
    region="san-francisco"
    @markerPress="onMarker"
  />
</template>
```

All attributes are forwarded to the native element as props, and the default slot is passed
through, so you can style and compose the custom component like any other.

## Notes

- The native factory must be registered **before** the component is created, or the bridge
  will log an "unknown component" warning and render nothing.
- Props are passed as JSON-serializable values; events fire through the normal event system.
- This is the same mechanism the built-in components use, so custom components get full
  layout (Yoga/Flexbox/LayoutNode) and styling support.
