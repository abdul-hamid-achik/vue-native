---
"@thelacanians/vue-native-runtime": minor
---

Devtools, image picking, and a native-component escape hatch.

- **`useInspector()`**: `dumpTree()` returns the live native view tree (`ViewTreeNode` — id, type, frame, children) serialized by the new native `Inspector` module. Useful for debugging layout and building devtools.
- **`useImagePicker()`**: `pickImage()` presents the platform photo picker (`PHPickerViewController` on iOS, system Photo Picker on Android, `NSOpenPanel` on macOS) and resolves to `{ uri, width, height }`, or `null` if cancelled. Exported `PickedImage` type.
- **`createNativeComponent(name)`**: escape hatch to embed a custom native component registered on the host. The native hosts now expose a public `registerComponent(name, factory)` API (iOS `VueNativeViewController`, Android `VueNativeActivity`, macOS `VueNativeWindowController`).

Docs added: `useInspector`, `useImagePicker`, and a "Custom Native Components" guide.
