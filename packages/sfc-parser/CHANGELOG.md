# @thelacanians/vue-native-sfc-parser

## 0.0.2

### Patch Changes

- 4bdb630: Fix `workspace:*` protocol that caused `npm error Unsupported URL Type "workspace:"` when installing packages globally. Replaced with `^0.0.1` semver ranges for internal dependencies (sfc-parser, codegen) that are bundled into dist at build time.
