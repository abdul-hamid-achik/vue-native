---
'@thelacanians/vue-native-cli': patch
---

`vue-native upgrade` warns outside git and records the version last.

Outside a git repository, local edits to `native/` cannot be detected, so
upgrade now says so before overwriting them. The version stamp is written after
the host patches, so a failed patch is retried on the next run.
