---
'@thelacanians/vue-native-cli': minor
---

macOS: `useFileSystem()` and `useDatabase()` are confined to per-app folders.

The macOS scaffold runs without the App Sandbox, so the FileSystem roots
resolved to `~/Documents`, `~/Library/Caches`, `~/Library/Application Support`
and the shared `$TMPDIR`. JavaScript could read and write every app's data
there. On a non-sandboxed host the roots are now
`~/Library/Application Support/<bundle id>`, `~/Library/Caches/<bundle id>` and
`$TMPDIR/<bundle id>`, and documents live in
`<Application Support>/<bundle id>/Documents`. `getDocumentsPath` and
`getCachesPath` report the new folders, and audio recordings and captured photos
are written to the per-app temporary folder so their paths stay readable.
Sandboxed hosts and iOS are unchanged.

Breaking for existing macOS apps: files written under `~/Documents`, and
databases in `~/Documents/databases`, are no longer reachable from JavaScript.
Move them into the new folders, or set
`FileSystemSandbox.shared.allowsUserDocumentsDirectory = true` from Swift at
launch to keep using the real `~/Documents` (this also restores the old database
location).
