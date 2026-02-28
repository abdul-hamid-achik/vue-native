# Composables

Vue Native exposes native device capabilities as Vue 3 composables.

All composables are exported from `@thelacanians/vue-native-runtime`.

## Device & System
- [useNetwork](./useNetwork.md) -- Network connectivity
- [useAppState](./useAppState.md) -- App foreground/background state
- [useColorScheme](./useColorScheme.md) -- Light/dark mode
- [useDeviceInfo](./useDeviceInfo.md) -- Device model, screen dimensions
- [useDimensions](./useDimensions.md) -- Screen and window dimensions
- [usePlatform](./usePlatform.md) -- Platform detection (iOS/Android/macOS)
- [useBackHandler](./useBackHandler.md) -- Android back button interception

## Storage & Files
- [useAsyncStorage](./useAsyncStorage.md) -- Persistent key-value store
- [useSecureStorage](./useSecureStorage.md) -- Encrypted key-value store (Keychain / EncryptedSharedPreferences)
- [useFileSystem](./useFileSystem.md) -- File system access
- [useDatabase](./useDatabase.md) -- SQLite database

## Sensors & Hardware
- [useGeolocation](./useGeolocation.md) -- GPS coordinates
- [useBiometry](./useBiometry.md) -- Face ID / Touch ID / Fingerprint
- [useHaptics](./useHaptics.md) -- Haptic feedback / vibration
- [useSensors](./useSensors.md) -- Accelerometer and gyroscope
- [useBluetooth](./useBluetooth.md) -- Bluetooth Low Energy

## Media
- [useCamera](./useCamera.md) -- Camera + photo library picker
- [useAudio](./useAudio.md) -- Audio playback and recording
- [useCalendar](./useCalendar.md) -- Calendar events
- [useContacts](./useContacts.md) -- Contacts access

## Networking
- [useHttp](./useHttp.md) -- HTTP client
- [useWebSocket](./useWebSocket.md) -- WebSocket connections

## Permissions
- [usePermissions](./usePermissions.md) -- Runtime permission requests

## Navigation
- [useSharedElementTransition](./useSharedElementTransition.md) -- Cross-screen animated transitions

## UI
- [useKeyboard](./useKeyboard.md) -- Keyboard visibility and height
- [useClipboard](./useClipboard.md) -- Copy and paste
- [useShare](./useShare.md) -- Native share sheet
- [useLinking](./useLinking.md) -- Open URLs
- [useAnimation](./useAnimation.md) -- Timing and spring animations
- [useNotifications](./useNotifications.md) -- Local notifications
- [useI18n](./useI18n.md) -- Locale and RTL detection
- [usePerformance](./usePerformance.md) -- FPS, memory, and bridge metrics

## Authentication
- [useAppleSignIn](./useAppleSignIn.md) -- Sign in with Apple
- [useGoogleSignIn](./useGoogleSignIn.md) -- Sign in with Google

## Monetization & Updates
- [useIAP](./useIAP.md) -- In-app purchases
- [useOTAUpdate](./useOTAUpdate.md) -- Over-the-air bundle updates
- [useBackgroundTask](./useBackgroundTask.md) -- Background task scheduling

## Desktop (macOS)

The following composables are available exclusively on macOS targets and expose desktop-specific capabilities.

- [useWindow](./useWindow.md) -- Control window size, position, title, and full-screen state
- [useMenu](./useMenu.md) -- Build and update the native macOS menu bar (NSMenu)
- [useFileDialog](./useFileDialog.md) -- Open and save panel dialogs for file system access
- [useDragDrop](./useDragDrop.md) -- Register views as drag sources or drop targets (NSDraggingDestination)
