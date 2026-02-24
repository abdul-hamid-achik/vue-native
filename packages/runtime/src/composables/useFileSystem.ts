import { NativeBridge } from '../bridge'

/**
 * File system access composable for reading, writing, and managing files.
 *
 * All operations are Promise-based and execute on a background thread.
 * Paths should be absolute — use getDocumentsPath() or getCachesPath()
 * to obtain app-scoped directories.
 *
 * @example
 * ```ts
 * const fs = useFileSystem()
 * const docsDir = await fs.getDocumentsPath()
 * await fs.writeFile(`${docsDir}/notes.txt`, 'Hello world')
 * const content = await fs.readFile(`${docsDir}/notes.txt`)
 * ```
 */
export interface FileStat {
  size: number
  isDirectory: boolean
  /** Last modified time in milliseconds since epoch */
  modified: number
}

export function useFileSystem() {
  /**
   * Read a file's contents.
   * @param path Absolute file path
   * @param encoding 'utf8' (default) returns string, 'base64' returns base64-encoded string
   */
  function readFile(path: string, encoding?: 'utf8' | 'base64'): Promise<string> {
    return NativeBridge.invokeNativeModule('FileSystem', 'readFile', [path, encoding ?? 'utf8'])
  }

  /**
   * Write content to a file. Creates parent directories if needed.
   * @param path Absolute file path
   * @param content String content to write
   * @param encoding 'utf8' (default) or 'base64' for binary data
   */
  function writeFile(path: string, content: string, encoding?: 'utf8' | 'base64'): Promise<void> {
    return NativeBridge.invokeNativeModule('FileSystem', 'writeFile', [path, content, encoding ?? 'utf8']).then(() => undefined)
  }

  /**
   * Delete a file or directory.
   */
  function deleteFile(path: string): Promise<void> {
    return NativeBridge.invokeNativeModule('FileSystem', 'deleteFile', [path]).then(() => undefined)
  }

  /**
   * Check if a file or directory exists at the given path.
   */
  function exists(path: string): Promise<boolean> {
    return NativeBridge.invokeNativeModule('FileSystem', 'exists', [path])
  }

  /**
   * List the contents of a directory.
   * @returns Array of file/directory names (not full paths)
   */
  function listDirectory(path: string): Promise<string[]> {
    return NativeBridge.invokeNativeModule('FileSystem', 'listDirectory', [path])
  }

  /**
   * Download a file from a URL and save it to the destination path.
   * @returns The destination path on success
   */
  function downloadFile(url: string, destPath: string): Promise<string> {
    return NativeBridge.invokeNativeModule('FileSystem', 'downloadFile', [url, destPath])
  }

  /**
   * Get the app's documents directory path. Suitable for user-generated content
   * that should persist and be backed up.
   */
  function getDocumentsPath(): Promise<string> {
    return NativeBridge.invokeNativeModule('FileSystem', 'getDocumentsPath', [])
  }

  /**
   * Get the app's caches directory path. Suitable for temporary data
   * that can be regenerated. May be purged by the OS under storage pressure.
   */
  function getCachesPath(): Promise<string> {
    return NativeBridge.invokeNativeModule('FileSystem', 'getCachesPath', [])
  }

  /**
   * Get file/directory metadata.
   */
  function stat(path: string): Promise<FileStat> {
    return NativeBridge.invokeNativeModule('FileSystem', 'stat', [path])
  }

  /**
   * Create a directory (and any missing parent directories).
   */
  function mkdir(path: string): Promise<void> {
    return NativeBridge.invokeNativeModule('FileSystem', 'mkdir', [path]).then(() => undefined)
  }

  /**
   * Copy a file. Overwrites destination if it exists.
   */
  function copyFile(srcPath: string, destPath: string): Promise<void> {
    return NativeBridge.invokeNativeModule('FileSystem', 'copyFile', [srcPath, destPath]).then(() => undefined)
  }

  /**
   * Move a file. Overwrites destination if it exists.
   */
  function moveFile(srcPath: string, destPath: string): Promise<void> {
    return NativeBridge.invokeNativeModule('FileSystem', 'moveFile', [srcPath, destPath]).then(() => undefined)
  }

  return {
    readFile,
    writeFile,
    deleteFile,
    exists,
    listDirectory,
    downloadFile,
    getDocumentsPath,
    getCachesPath,
    stat,
    mkdir,
    copyFile,
    moveFile,
  }
}
