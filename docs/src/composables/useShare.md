# useShare

Show the native share sheet to share text content and URLs with other apps.

## Usage

```vue
<script setup>
import { useShare } from '@thelacanians/vue-native-runtime'

const { share } = useShare()

async function shareContent() {
  const result = await share({
    message: 'Check out Vue Native!',
    url: 'https://example.com'
  })
  if (result.shared) {
    console.log('Shared successfully')
  }
}
</script>
```

## API

```ts
useShare(): {
  share: (content: ShareContent) => Promise<ShareResult>
}
```

### Parameters

The `share` function accepts a `ShareContent` object:

| Property | Type | Description |
|----------|------|-------------|
| `message` | `string?` | Text message to share. |
| `url` | `string?` | URL to share. |

At least one of `message` or `url` should be provided.

### Return Value

The `share` function returns a `Promise<ShareResult>`:

| Property | Type | Description |
|----------|------|-------------|
| `shared` | `boolean` | `true` if the user completed the share action, `false` if they cancelled. |

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses `UIActivityViewController` to present the system share sheet. |
| Android | Uses `Intent.ACTION_SEND` with `Intent.createChooser`. |

## Example

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'
import { useShare } from '@thelacanians/vue-native-runtime'

const { share } = useShare()
const status = ref('')

async function shareLink() {
  const result = await share({
    message: 'Built with Vue Native',
    url: 'https://example.com'
  })
  status.value = result.shared ? 'Shared!' : 'Cancelled'
}

async function shareText() {
  await share({ message: 'Hello from Vue Native!' })
}
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VButton title="Share Link" :onPress="shareLink" />
    <VButton title="Share Text" :onPress="shareText" />
    <VText :style="{ marginTop: 16 }">{{ status }}</VText>
  </VView>
</template>
```

## Notes

- The share sheet is a system-provided UI. You cannot customize its appearance.
- On iOS, both `message` and `url` are passed as activity items. Some share targets may use one or both.
- The returned `shared` boolean may not be fully reliable on all platforms -- some share extensions do not report completion status.
