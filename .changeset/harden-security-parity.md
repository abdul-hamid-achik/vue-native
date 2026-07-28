---
"@thelacanians/vue-native-runtime": minor
"@thelacanians/vue-native-cli": minor
---

Security hardening, type-safe runtime APIs, and cross-platform parity improvements.

**Breaking (types):**

- `NativeBridge.invokeNativeModule` is now generic (`invokeNativeModule<T = unknown>()`) instead of returning `Promise<any>`. Call sites with a typed left-hand side are verified automatically; `.then()` call sites need an explicit type argument.
- `HttpResponse<T>.data` is now `T | undefined` (204/205 responses have no body).
- Removed style properties the native renderer never implemented: `borderStyle`, `textDecorationStyle`, `textDecorationColor`, and `overflow: 'scroll'`. `padding`/`margin` are now `number` only (percentage values were never applied). Use `<VScrollView>` for scrolling.

**Security:**

- OTA updates are HTTPS-only and routed through certificate pinning on iOS.
- OTA publisher authentication: `useOTAUpdate(url, { verifyKey })` verifies an ECDSA (P-256) signature over the bundle before applying it (iOS CryptoKit, Android `SHA256withECDSA`). Falls back to SHA-256-only with a warning when no key is configured.
- `vue-native dev` now binds to localhost by default; pass `--lan` to expose it to the local network for physical-device development.

**Added:**

- `selectPlatform()` helper (React Native-style `Platform.select`) and `StyleSheet.hairlineWidth`.
- 3D transforms: `perspective`, `skewX`, `skewY` (alongside `rotateX/Y/Z`) on iOS/macOS (`CATransform3D`); `rotateX/Y/Z` + `cameraDistance` on Android.
- Local image assets: `<VImage :source="{ asset: 'logo' }" />` loads bundled images (iOS Asset Catalog, macOS named image, Android `res/drawable`). Exported `ImageSource` type.
- `VFlatList` is now generic: `renderItem`/`keyExtractor` infer the item type from `data`.
- The bridge emits a subscribable `bridge:error` global event (and a throttled console error) when the native runtime is not connected, instead of a single buried warning.
- `invokeNativeModule(..., timeoutMs)` accepts `0` to disable the timeout for long-running operations; `useOTAUpdate.downloadUpdate` uses this so a slow download is no longer cancelled and cleaned up mid-flight.
- Style props that were implemented natively but missing from the types: `paddingStart`/`paddingEnd`, `marginStart`/`marginEnd`, `elevation` (Android). `accessibilityState` is now a typed interface.

**Fixed (native parity):**

- Consistent color parsing across platforms: 8-digit hex is `#RRGGBBAA` (alpha last) everywhere; added `#RGB`/`#RGBA`, `rgb()`/`rgba()` (with alpha), and a shared named-color set. Invalid colors keep the previous style and log a warning instead of rendering transparent (Apple) or being silently dropped (Android).
- Android: adaptive dark-mode-aware text color, button press feedback, V8 stack traces in the error overlay, `aspectRatio`, throttled list scroll events, input focus affordance.
- iOS: DEBUG logging for bridge operations dropped on unknown nodes and for unknown component types; lazy list row measurement; `accessibilityRole` preserves reactive traits; Dynamic Type scaling.
- macOS: `secureTextEntry` now masks input, `VList` uses targeted row insert/remove, `align-items: stretch` no longer overrides a definite cross-axis size, `importantForAccessibility`, `VVideo` play/pause events.
- Docs: added local search, surfaced previously orphaned pages (`VDrawer`, navigation-components guide, `useTeleport`), and corrected broken examples (`useAnimation`, `VSuspense`, `useTeleport`, `VInput`).
