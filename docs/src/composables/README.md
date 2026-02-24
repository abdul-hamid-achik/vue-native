# Composables

Vue Native exposes native device capabilities as Vue 3 composables.

All composables are exported from `@thelacanians/vue-native-runtime`.

## Device & System
- [useNetwork](./useNetwork.md) -- Network connectivity
- [useAppState](./useAppState.md) -- App foreground/background state
- [useColorScheme](./useColorScheme.md) -- Light/dark mode
- [useDeviceInfo](./useDeviceInfo.md) -- Device model, screen dimensions
- [useBackHandler](./useBackHandler.md) -- Android back button interception

## Storage
- [useAsyncStorage](./useAsyncStorage.md) -- Persistent key-value store
- [useSecureStorage](./useSecureStorage.md) -- Encrypted key-value store (Keychain / EncryptedSharedPreferences)

## Sensors & Hardware
- [useGeolocation](./useGeolocation.md) -- GPS coordinates
- [useBiometry](./useBiometry.md) -- Face ID / Touch ID / Fingerprint
- [useHaptics](./useHaptics.md) -- Haptic feedback / vibration

## Media
- [useCamera](./useCamera.md) -- Camera + photo library picker

## Permissions
- [usePermissions](./usePermissions.md) -- Runtime permission requests

## UI
- [useKeyboard](./useKeyboard.md) -- Keyboard visibility and height
- [useClipboard](./useClipboard.md) -- Copy and paste
- [useShare](./useShare.md) -- Native share sheet
- [useLinking](./useLinking.md) -- Open URLs
- [useAnimation](./useAnimation.md) -- Timing and spring animations
- [useHttp](./useHttp.md) -- HTTP client
- [useNotifications](./useNotifications.md) -- Local notifications
- [useI18n](./useI18n.md) -- Locale and RTL detection
