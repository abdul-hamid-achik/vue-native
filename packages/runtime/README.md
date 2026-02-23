# @thelacanians/vue-native-runtime

Vue 3 custom renderer for building native iOS and Android apps.

## Install

```bash
npm install @thelacanians/vue-native-runtime
# or
bun add @thelacanians/vue-native-runtime
```

## Usage

```ts
import { createApp } from 'vue'
import App from './App.vue'

const app = createApp(App)
app.start()
```

> **Note:** The Vite plugin aliases `'vue'` to this package automatically, so you import from `'vue'` in your app code.

## What's included

### Components

| Component | Description |
|-----------|-------------|
| `VView` | Flexbox container (like `<div>`) |
| `VText` | Text display |
| `VButton` | Pressable button |
| `VInput` | Text input field |
| `VSwitch` | Toggle switch |
| `VSlider` | Numeric slider |
| `VScrollView` | Scrollable container with pull-to-refresh |
| `VList` | Virtualized list (UITableView / RecyclerView) |
| `VImage` | Image display (local + remote) |
| `VSafeArea` | Safe area insets container |
| `VKeyboardAvoiding` | Keyboard-aware container |
| `VModal` | Modal overlay |
| `VAlertDialog` | Native alert dialog |
| `VActionSheet` | Action sheet |
| `VStatusBar` | Status bar configuration |
| `VWebView` | Embedded web view |
| `VProgressBar` | Progress indicator |
| `VPicker` | Value picker |
| `VSegmentedControl` | Segmented control |
| `VActivityIndicator` | Loading spinner |

### Composables

| Composable | Description |
|------------|-------------|
| `useAnimation` | Timing and spring animations |
| `useAsyncStorage` | Persistent key-value storage |
| `useBackHandler` | Hardware back button (Android) |
| `useBiometry` | Face ID / Touch ID / Fingerprint |
| `useCamera` | Camera access |
| `useClipboard` | System clipboard |
| `useColorScheme` | Light/dark mode |
| `useDeviceInfo` | Device model, OS, screen size |
| `useGeolocation` | GPS location |
| `useHaptics` | Haptic feedback |
| `useHttp` | HTTP client (fetch wrapper) |
| `useKeyboard` | Keyboard visibility and height |
| `useLinking` | Deep links and URL opening |
| `useNetwork` | Network connectivity status |
| `useNotifications` | Local notifications |
| `usePermissions` | Runtime permissions |
| `useShare` | Native share sheet |
| `useAppState` | App foreground/background state |

### Utilities

- `createStyleSheet()` - Type-safe style definitions with dev-mode validation
- `vShow` - Directive for toggling visibility
- `NativeBridge` - Low-level native interop

## Styling

```ts
import { createStyleSheet } from 'vue'

const styles = createStyleSheet({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#ffffff',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1a1a1a',
  },
})
```

## Platforms

- **iOS 16+** — JavaScriptCore + UIKit via [VueNativeCore](https://github.com/abdul-hamid-achik/vue-native/tree/main/native/ios) Swift package
- **Android 5.0+** — V8 (J2V8) + Android Views via [VueNativeCore](https://github.com/abdul-hamid-achik/vue-native/tree/main/native/android) Kotlin library

## License

MIT
