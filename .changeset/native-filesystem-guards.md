---
'@thelacanians/vue-native-cli': patch
---

FileSystem: protected trees, redirect checks, and real directory moves on Android.

`copyFile`, `moveFile` and `downloadFile` refuse to replace or move a sandbox
root or an ancestor of the OTA store on iOS, macOS and Android. `downloadFile`
re-checks every redirect, so an https download cannot be redirected to
cleartext. On Android, copying or moving a directory now carries its contents
instead of reporting success with an empty target.
