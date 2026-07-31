---
"@thelacanians/vue-native-cli": minor
---

Add interactive prompts and a [@clack/prompts](https://www.npmjs.com/package/@clack/prompts) UI across the CLI:

- `vue-native create` now prompts for the project name and template when they are omitted, with live validation.
- `vue-native run` and `vue-native build` prompt for the target platform when it is omitted.
- All commands render with the clack UI (intro, step/success/warn logs, notes, outro).

Non-interactive usage is unchanged: when stdin is not a TTY, missing required arguments still produce a clear error instead of waiting for input.
