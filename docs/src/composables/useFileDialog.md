# useFileDialog

Open native macOS file dialogs for selecting files, directories, and saving files. Wraps `NSOpenPanel` and `NSSavePanel`.

## Usage

```vue
<script setup>
import { useFileDialog } from '@thelacanians/vue-native-runtime'

const { openFile, openDirectory, saveFile } = useFileDialog()

async function handleOpen() {
  const files = await openFile({
    allowedTypes: ['png', 'jpg', 'jpeg'],
    multiple: true,
  })
  if (files) {
    console.log('Selected:', files)
  }
}

async function handleSave() {
  const path = await saveFile({
    defaultName: 'document.txt',
  })
  if (path) {
    console.log('Save to:', path)
  }
}
</script>
```

## API

```ts
useFileDialog(): {
  openFile: (options?: OpenFileOptions) => Promise<string[] | null>
  openDirectory: (options?: { title?: string }) => Promise<string | null>
  saveFile: (options?: SaveFileOptions) => Promise<string | null>
}
```

### Return Value

| Method | Signature | Description |
|--------|-----------|-------------|
| `openFile` | `(options?) => Promise<string[] \| null>` | Show a file open dialog. Returns an array of selected file paths, or `null` if cancelled. |
| `openDirectory` | `(options?) => Promise<string \| null>` | Show a directory picker dialog. Returns the selected directory path, or `null` if cancelled. |
| `saveFile` | `(options?) => Promise<string \| null>` | Show a file save dialog. Returns the chosen save path, or `null` if cancelled. |

### Types

```ts
interface OpenFileOptions {
  /** Allow selecting multiple files. Defaults to false. */
  multiple?: boolean
  /** Allowed file extensions (e.g. ['png', 'jpg']). Omit to allow all files. */
  allowedTypes?: string[]
  /** Window title. Defaults to 'Open'. */
  title?: string
}

interface SaveFileOptions {
  /** Window title. Defaults to 'Save'. */
  title?: string
  /** Default file name shown in the save field. */
  defaultName?: string
}
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | No — iOS uses `UIDocumentPickerViewController` via `useFileSystem`. |
| Android | No — Android uses the Storage Access Framework via `useFileSystem`. |
| macOS | Yes — Uses `NSOpenPanel` and `NSSavePanel`. |

## Example

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'
import { useFileDialog } from '@thelacanians/vue-native-runtime'

const { openFile, openDirectory, saveFile } = useFileDialog()
const selectedPaths = ref<string[]>([])
const savedPath = ref('')

async function pickImages() {
  const files = await openFile({
    title: 'Select Images',
    allowedTypes: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
    multiple: true,
  })
  if (files) {
    selectedPaths.value = files
  }
}

async function pickFolder() {
  const dir = await openDirectory({ title: 'Choose Output Folder' })
  if (dir) {
    selectedPaths.value = [dir]
  }
}

async function saveDocument() {
  const path = await saveFile({
    title: 'Save Document',
    defaultName: 'untitled.md',
  })
  if (path) {
    savedPath.value = path
  }
}
</script>

<template>
  <VView :style="{ padding: 20, gap: 12 }">
    <VText :style="{ fontSize: 18, fontWeight: 'bold' }">File Dialog Demo</VText>

    <VButton :onPress="pickImages"><VText>Pick Images</VText></VButton>
    <VButton :onPress="pickFolder"><VText>Pick Folder</VText></VButton>
    <VButton :onPress="saveDocument"><VText>Save Document</VText></VButton>

    <VView v-if="selectedPaths.length > 0" :style="{ marginTop: 16 }">
      <VText :style="{ fontWeight: 'bold' }">Selected:</VText>
      <VText v-for="(p, i) in selectedPaths" :key="i">{{ p }}</VText>
    </VView>

    <VText v-if="savedPath" :style="{ marginTop: 16 }">
      Saved to: {{ savedPath }}
    </VText>
  </VView>
</template>
```

## Notes

- All three methods return Promises that resolve when the user confirms or cancels the dialog.
- Returns `null` when the user cancels — always check the return value.
- File paths are absolute POSIX paths (e.g. `/Users/name/Documents/file.txt`).
- Calling these methods on iOS or Android is a no-op that returns `null`.
- The `allowedTypes` array in `OpenFileOptions` uses file extensions without dots (e.g. `'png'`, not `'.png'`).
- `SaveFileOptions` does not support `allowedTypes` — the save panel accepts any file name the user types.
