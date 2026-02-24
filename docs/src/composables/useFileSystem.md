# useFileSystem

File system access for reading, writing, and managing files on the device. Provides a complete set of async operations for working with the local file system, including file I/O, directory management, and file downloads.

## Usage

```vue
<script setup>
import { ref } from 'vue'
import { useFileSystem } from '@thelacanians/vue-native-runtime'

const { readFile, writeFile, getDocumentsPath, exists } = useFileSystem()
const content = ref('')

async function loadNotes() {
  const docsPath = await getDocumentsPath()
  const filePath = `${docsPath}/notes.txt`
  if (await exists(filePath)) {
    content.value = await readFile(filePath)
  }
}

async function saveNotes() {
  const docsPath = await getDocumentsPath()
  await writeFile(`${docsPath}/notes.txt`, content.value)
}
</script>

<template>
  <VView>
    <VInput v-model="content" placeholder="Write your notes..." />
    <VButton title="Save" @press="saveNotes" />
    <VButton title="Load" @press="loadNotes" />
  </VView>
</template>
```

## API

```ts
useFileSystem(): {
  readFile: (path: string, encoding?: FileEncoding) => Promise<string>,
  writeFile: (path: string, content: string, encoding?: FileEncoding) => Promise<void>,
  deleteFile: (path: string) => Promise<void>,
  exists: (path: string) => Promise<boolean>,
  listDirectory: (path: string) => Promise<string[]>,
  downloadFile: (url: string, destPath: string) => Promise<void>,
  getDocumentsPath: () => Promise<string>,
  getCachesPath: () => Promise<string>,
  stat: (path: string) => Promise<FileStat>,
  mkdir: (path: string) => Promise<void>,
  copyFile: (src: string, dest: string) => Promise<void>,
  moveFile: (src: string, dest: string) => Promise<void>
}
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `readFile` | `(path: string, encoding?: FileEncoding) => Promise<string>` | Read the contents of a file as a string. |
| `writeFile` | `(path: string, content: string, encoding?: FileEncoding) => Promise<void>` | Write string content to a file. Creates the file if it does not exist. |
| `deleteFile` | `(path: string) => Promise<void>` | Delete a file at the specified path. |
| `exists` | `(path: string) => Promise<boolean>` | Check whether a file or directory exists at the given path. |
| `listDirectory` | `(path: string) => Promise<string[]>` | List the names of all files and subdirectories in a directory. |
| `downloadFile` | `(url: string, destPath: string) => Promise<void>` | Download a file from a remote URL and save it to the destination path. |
| `getDocumentsPath` | `() => Promise<string>` | Get the absolute path to the app's documents directory. |
| `getCachesPath` | `() => Promise<string>` | Get the absolute path to the app's caches directory. |
| `stat` | `(path: string) => Promise<FileStat>` | Get metadata about a file or directory. |
| `mkdir` | `(path: string) => Promise<void>` | Create a directory at the specified path, including intermediate directories. |
| `copyFile` | `(src: string, dest: string) => Promise<void>` | Copy a file from the source path to the destination path. |
| `moveFile` | `(src: string, dest: string) => Promise<void>` | Move a file from the source path to the destination path. |

### Types

```ts
type FileEncoding = 'utf8' | 'base64'

interface FileStat {
  /** File size in bytes. */
  size: number
  /** Whether the path is a directory. */
  isDirectory: boolean
  /** Last modification timestamp in milliseconds since epoch. */
  modified: number
}
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses `FileManager` for all file operations. Documents and caches directories map to the standard iOS sandbox locations. |
| Android | Uses `java.io.File` for all file operations. Documents directory maps to the app's internal files directory. Caches directory maps to the app's cache directory. |

## Example

```vue
<script setup>
import { ref } from 'vue'
import { useFileSystem } from '@thelacanians/vue-native-runtime'

const { listDirectory, getDocumentsPath, stat, deleteFile, downloadFile } = useFileSystem()
const files = ref([])

async function refreshFiles() {
  const docsPath = await getDocumentsPath()
  const names = await listDirectory(docsPath)
  const entries = []
  for (const name of names) {
    const info = await stat(`${docsPath}/${name}`)
    entries.push({ name, ...info })
  }
  files.value = entries
}

async function removeFile(name) {
  const docsPath = await getDocumentsPath()
  await deleteFile(`${docsPath}/${name}`)
  await refreshFiles()
}

async function download() {
  const docsPath = await getDocumentsPath()
  await downloadFile('https://example.com/data.json', `${docsPath}/data.json`)
  await refreshFiles()
}
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VText :style="{ fontSize: 24, marginBottom: 16 }">File Manager</VText>
    <VButton title="Refresh" @press="refreshFiles" />
    <VButton title="Download File" @press="download" />

    <VView v-for="file in files" :key="file.name" :style="{ flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 8 }">
      <VText>{{ file.name }} ({{ file.size }} bytes)</VText>
      <VButton title="Delete" @press="removeFile(file.name)" />
    </VView>
  </VView>
</template>
```

## Notes

- All operations are asynchronous and run on background threads to avoid blocking the UI.
- The default encoding is `'utf8'`. Use `'base64'` for binary files such as images.
- `writeFile` creates the file if it does not exist and overwrites it if it does.
- `mkdir` creates intermediate directories as needed (equivalent to `mkdir -p`).
- `downloadFile` uses native HTTP clients (`URLSession` on iOS, `OkHttp` on Android) for efficient background downloads.
- File paths must be absolute. Use `getDocumentsPath()` or `getCachesPath()` to build paths relative to known directories.
- Files in the documents directory are persisted across app launches and included in device backups. Files in the caches directory may be purged by the system under storage pressure.
