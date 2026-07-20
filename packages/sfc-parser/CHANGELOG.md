# @thelacanians/vue-native-sfc-parser

## 0.6.7

### Patch Changes

- 8f8b777: Keep every workspace and generated app on one exact Vue dependency cohort,
  validate physical runtime duplication, and exercise Vue 3.6 compatibility in a
  non-publishing CI lane. Reject unsupported Vapor SFC modes early and keep the
  native renderer isolated from DOM renderer aliases.

## 0.6.6

### Patch Changes

- edaa4d4: Correct public documentation and examples for platform-targeted development,
  WebSocket and Android host lifecycle APIs, and native-block code generation.
  Package guidance now uses executable commands, current native-module
  signatures, canonical output paths, and collision-free example module names.

## 0.6.5

### Patch Changes

- b1d4eb3: Run custom native-block validators, derive component names correctly from Windows paths, and report deterministic directory-scan errors instead of throwing.

## 0.0.2

### Patch Changes

- 4bdb630: Fix `workspace:*` protocol that caused `npm error Unsupported URL Type "workspace:"` when installing packages globally. Replaced with `^0.0.1` semver ranges for internal dependencies (sfc-parser, codegen) that are bundled into dist at build time.
