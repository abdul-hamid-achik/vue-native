# useClipboard

Read and write text to the system clipboard. Provides a reactive `content` ref that updates when you read from the clipboard.

## Usage

```vue
<script setup>
import { useClipboard } from '@thelacanians/vue-native-runtime'

const { copy, paste, content } = useClipboard()

async function copyText() {
  await copy('Hello, World!')
}

async function pasteText() {
  const text = await paste()
  console.log('Pasted:', text)
}
</script>
```

## API

```ts
useClipboard(): {
  content: Ref<string>
  copy: (text: string) => Promise<void>
  paste: () => Promise<string>
}
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `content` | `Ref<string>` | The last pasted clipboard content. Updated each time `paste()` is called. Defaults to `''`. |
| `copy` | `(text: string) => Promise<void>` | Copy text to the system clipboard. |
| `paste` | `() => Promise<string>` | Read text from the system clipboard. Also updates the `content` ref. |

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses `UIPasteboard.general` for read/write access. |
| Android | Uses `ClipboardManager` system service. |

## Example

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'
import { useClipboard } from '@thelacanians/vue-native-runtime'

const { copy, paste, content } = useClipboard()
const inputText = ref('')

async function handleCopy() {
  await copy(inputText.value)
}

async function handlePaste() {
  await paste()
  // content.value is now updated with clipboard text
}
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VInput
      :value="inputText"
      :onChangeText="(t) => inputText = t"
      placeholder="Type text to copy"
      :style="{ borderWidth: 1, borderColor: '#ccc', padding: 10 }"
    />

    <VButton title="Copy to Clipboard" :onPress="handleCopy" />
    <VButton title="Paste from Clipboard" :onPress="handlePaste" />

    <VText :style="{ marginTop: 16 }">
      Clipboard content: {{ content }}
    </VText>
  </VView>
</template>
```

## Notes

- The `content` ref only updates when `paste()` is called. It does not automatically sync with the system clipboard.
- On iOS 14+, the system shows a paste notification banner when an app reads the clipboard. This is expected behavior.
- Both `copy` and `paste` are asynchronous because they cross the native bridge.
