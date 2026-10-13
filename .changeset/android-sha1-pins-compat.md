---
'@thelacanians/vue-native-cli': patch
---

Android accepts `sha1/` certificate pins again, fixing a 0.23.0 regression.

0.23.0 started treating `sha1/` pins as malformed on Android, and the same
release refuses a host whose pins are all malformed, so an app that pinned a
host only with `sha1/` hashes could no longer connect to it. `sha1/` pins are
valid again on Android and log a deprecation warning. They have never worked
on iOS or macOS; move to `sha256/` pins, which every platform accepts.
