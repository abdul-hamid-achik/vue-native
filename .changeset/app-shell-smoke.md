---
"@thelacanians/vue-native-cli": patch
---

Add a committed app-shell fixture and host-boot smoke. `vue-native` hosts can load `fixtures/app-shell/vue-native-bundle.js` and expose stable accessibility ids (`app-shell-root`, `app-shell-label`). `bun run smoke:app-shell` writes `artifacts/app-shell-smoke.json` with per-platform pass/skip reasons. Physical-device evidence stays separate.
