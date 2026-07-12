---
"@thelacanians/vue-native-cli": patch
"@thelacanians/vue-native-vite-plugin": patch
---

Make the selected iOS, Android, or macOS CLI target authoritative in Vite, including for configs with an existing explicit platform. Validate platform environment values, expose the scaffolded platform constant type, and reject contradictory multi-platform development commands.
