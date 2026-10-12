---
'@thelacanians/vue-native-cli': patch
---

macOS: aspect-ratio flex items, menu modifiers, and `<VSVG>` loads.

- A flex item with a definite cross size and an `aspectRatio` uses the ratio as
  its flex basis, so growing siblings no longer overflow the container.
- A negative menu `modifiers` value no longer crashes the app, and menu
  rebuilds release the item proxies they replace.
- Remote `<VSVG>` loads honour certificate pinning, and local SVG paths are
  confined to the FileSystem sandbox.
