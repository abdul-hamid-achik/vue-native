# Debugging

## Console Logging

`console.log`, `console.warn`, and `console.error` are polyfilled in the JS runtime and forwarded to native:

- **iOS:** Output appears in Xcode's console (`NSLog`)
- **Android:** Output appears in Logcat (tag: `VueNative JS`)

```ts
console.log('User data:', user.value)
console.warn('Deprecated API used')
console.error('Something went wrong:', error)
```

Filter logs in Xcode by searching for `[VueNative]`, or in Logcat with `adb logcat | grep VueNative`.

## Safari Web Inspector (iOS)

You can attach Safari's debugger to the JavaScriptCore context running in the iOS Simulator:

1. Open **Safari** > **Settings** > **Advanced** > enable **"Show features for web developers"**
2. Run your app on the iOS Simulator
3. In Safari's menu bar: **Develop** > **Simulator** > select your app
4. The Web Inspector opens with:
   - **Console** — see logs, execute JS
   - **Sources** — view bundled source, set breakpoints (requires `sourcemap: true` in Vite config)
   - **Network** — inspect fetch requests

**Note:** This only works with the Simulator, not physical devices (JavaScriptCore doesn't expose its debug protocol over USB the way WebKit does).

## Android Studio Logcat

For Android, use Logcat in Android Studio:

1. Run your app on an emulator or device
2. Open **Logcat** panel in Android Studio
3. Filter by `VueNative` to see bridge operations, JS logs, and errors

For V8 debugging, the JS context doesn't natively support Chrome DevTools Protocol. Use console logging as the primary debugging method on Android.

## Bridge Operation Logging

The native bridge logs every operation batch. To see exactly what the JS renderer sends to native:

```
[VueNative Bridge] Processing 5 operations
```

In development mode, you can inspect bridge traffic by watching for `[VueNative Bridge]` in the console output. Each log shows the operation count per batch.

## Error Overlay

In development, unhandled errors in components trigger an error overlay on the native side showing:

- Error message
- Component name where the error occurred
- Stack trace

The overlay is managed by `app.config.errorHandler` which serializes errors and sends them to the native error display via `__VN_handleError`.

## Common Issues

### "\_\_VN\_flushOperations is not registered"

The JS bundle loaded before the native bridge finished initializing. Ensure `NativeBridge.initialize()` is called before evaluating the JS bundle in your AppDelegate/Activity.

### Styles not updating

If you change a layout-affecting style (e.g. `width`, `padding`, `flex`) and nothing happens, ensure you're updating via a reactive ref or computed property. Static style objects don't trigger re-renders:

```ts
// Won't update:
const style = { width: 100 }
style.width = 200  // Not reactive

// Will update:
const width = ref(100)
// In template: :style="{ width: width }"
width.value = 200  // Triggers re-render
```

### Hot reload not connecting

- Check that the dev server is running (`bun run dev`)
- iOS Simulator: connects to `ws://localhost:8174`
- Android Emulator: connects to `ws://10.0.2.2:8174` (host loopback)
- Physical device: connects to `ws://<your-lan-ip>:8174` (printed in dev server output)

### Blank screen on launch

Check the Xcode/Logcat console for errors. Common causes:
- JS bundle not found at the expected path
- Bundle evaluation error (syntax error, missing polyfill)
- Root view bounds are zero (AutoLayout not resolved yet)

## Testing & Mocking

For unit testing, see the [Testing Guide](/guide/testing.md). Use the exported mock bridge:

```ts
import { installMockBridge, nextTick } from '@thelacanians/vue-native-runtime/testing'

const { getOps, getOpsByType, reset } = installMockBridge()
```
