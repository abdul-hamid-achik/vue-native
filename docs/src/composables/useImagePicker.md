# useImagePicker

Present the platform photo picker and get the selected image. Backed by the native
`ImagePicker` module (`PHPickerViewController` on iOS, the system Photo Picker on Android,
`NSOpenPanel` on macOS).

## API

```ts
const { pickImage } = useImagePicker()
```

| Method | Signature | Description |
|--------|-----------|-------------|
| `pickImage` | `(options?) => Promise<PickedImage \| null>` | Present the picker; resolves to the image, or `null` if cancelled. |

### `PickedImage`

```ts
interface PickedImage {
  uri: string      // file URI of a temp copy you own
  width: number    // pixel width
  height: number   // pixel height
}
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `mediaType` | `'photo'` | `'photo'` | The kind of media to pick. |

## Example

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { useImagePicker, usePermissions, VButton, VImage, VText } from '@thelacanians/vue-native-runtime'

const { pickImage } = useImagePicker()
const { request } = usePermissions()
const photo = ref<{ uri: string } | null>(null)

async function choose() {
  await request('photos')
  photo.value = await pickImage()
}
</script>

<template>
  <VButton title="Choose photo" @press="choose" />
  <VImage v-if="photo" :source="{ uri: photo.uri }" :style="{ width: 200, height: 200 }" />
</template>
```

## Notes

- Requires the photos permission — request it with [`usePermissions`](./usePermissions.md).
- The returned `uri` is a temporary file you own; copy it if you need to keep it.
- Resolves to `null` when the user cancels.
