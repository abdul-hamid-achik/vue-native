# VImage

Displays images from remote URLs or bundled local assets. Maps to `UIImageView` on iOS and `ImageView` (powered by Coil) on Android. Images are loaded asynchronously with built-in memory caching.

## Usage

```vue
<!-- Remote image -->
<VImage
  :source="{ uri: 'https://example.com/photo.jpg' }"
  resizeMode="cover"
  :style="{ width: 200, height: 150, borderRadius: 8 }"
/>

<!-- Bundled local asset -->
<VImage
  :source="{ asset: 'logo' }"
  :style="{ width: 120, height: 40 }"
/>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `source` | `ImageSource` (`{ uri?: string; asset?: string }`) | -- | Image source object. Provide `uri` for a remote/absolute URL, or `asset` to load a bundled image by name. Set exactly one. |
| `resizeMode` | `'cover' \| 'contain' \| 'stretch' \| 'center'` | `'cover'` | How the image is scaled to fit its container |
| `style` | `Object` | -- | Layout + appearance styles (width and height recommended) |
| `testID` | `string` | -- | Test identifier for end-to-end testing |
| `accessibilityLabel` | `string` | -- | Accessible description of the image |
| `accessibilityRole` | `string` | -- | The accessibility role (e.g. `'image'`) |
| `accessibilityHint` | `string` | -- | Describes what happens when the user interacts with the element |
| `accessibilityState` | `Object` | -- | Accessibility state object |

### Resize Modes

| Mode | Description |
|------|-------------|
| `cover` | Scale to fill the container, cropping if needed (default) |
| `contain` | Scale to fit within the container, preserving aspect ratio |
| `stretch` | Stretch to fill the exact dimensions of the container |
| `center` | Center without scaling |

## Local assets

Set `source.asset` to the name of an image bundled with your app to load it from
the platform's native asset store instead of the network:

```vue
<VImage :source="{ asset: 'logo' }" :style="{ width: 120, height: 40 }" />
```

The name resolves against each platform's asset system:

| Platform | Resolved from |
|----------|---------------|
| iOS | Asset Catalog (`.xcassets`) image set name |
| macOS | Named image (`NSImage(named:)`) |
| Android | `res/drawable` resource name (without extension) |

The `ImageSource` type is exported from the runtime if you need it in TypeScript:

```ts
import type { ImageSource } from '@thelacanians/vue-native-runtime'

const source: ImageSource = { asset: 'logo' }
```

::: tip
Provide exactly one of `uri` or `asset`. Asset loading is synchronous and does
not fire network caching, but `@load` / `@error` still fire so you can react to
a missing asset.
:::

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@load` | -- | Fired when the image finishes loading |
| `@error` | `{ message: string }` | Fired when the image fails to load |

## Example

```vue
<script setup>
import { ref } from 'vue'

const loaded = ref(false)
const error = ref('')

const onLoad = () => {
  loaded.value = true
}

const onError = (e) => {
  error.value = e.message
}
</script>

<template>
  <VView :style="styles.container">
    <VImage
      :source="{ uri: 'https://picsum.photos/400/300' }"
      resizeMode="cover"
      :style="styles.image"
      accessibilityLabel="Random landscape photo"
      @load="onLoad"
      @error="onError"
    />
    <VText v-if="loaded" :style="styles.caption">Image loaded</VText>
    <VText v-if="error" :style="styles.error">{{ error }}</VText>

    <VView :style="styles.row">
      <VImage
        :source="{ uri: 'https://picsum.photos/100/100' }"
        resizeMode="cover"
        :style="styles.avatar"
      />
      <VText :style="styles.name">Jane Doe</VText>
    </VView>
  </VView>
</template>

<script>
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  container: {
    flex: 1,
    padding: 16,
  },
  image: {
    width: '100%',
    height: 200,
    borderRadius: 12,
  },
  caption: {
    marginTop: 8,
    color: '#34C759',
    fontSize: 14,
  },
  error: {
    marginTop: 8,
    color: '#FF3B30',
    fontSize: 14,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 24,
  },
  avatar: {
    width: 48,
    height: 48,
    borderRadius: 24,
  },
  name: {
    marginLeft: 12,
    fontSize: 16,
    fontWeight: '600',
  },
})
</script>
```

::: tip
Always set explicit `width` and `height` on `VImage` styles. Without dimensions the layout engine cannot reserve space before the image loads, which causes content jumps.
:::
