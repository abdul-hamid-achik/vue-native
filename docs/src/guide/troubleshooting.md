# Troubleshooting

This page covers common problems you may encounter when building with Vue Native, organized by category. For error handling APIs and reporting integrations, see the [Error Handling](./error-handling.md) and [Error Reporting & Monitoring](./error-reporting.md) guides.

## Build Issues

### Xcode Build Fails

**"Signing for 'VueNativeCore' requires a development team"**

Xcode requires a signing identity even for Simulator builds. Open your `.xcodeproj` or `.xcworkspace`, select the VueNativeCore target, and set a development team under Signing & Capabilities.

```
Xcode -> Target -> Signing & Capabilities -> Team -> Select your team
```

**"No such module 'FlexLayout'"**

The FlexLayout Swift Package dependency has not been resolved. In Xcode:

1. File -> Packages -> Resolve Package Versions.
2. If that does not work, delete the `DerivedData` folder and rebuild:
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
```

**"Compiling for iOS 15.0, but module was compiled for iOS 16.0"**

Vue Native targets iOS 16.0+. Check that your project's minimum deployment target is set to at least iOS 16.0:

```
Xcode -> Target -> General -> Minimum Deployments -> iOS 16.0
```

**Swift version mismatch**

Vue Native requires Swift 5.9+. Verify your Xcode version supports it:

```bash
swift --version
# Expected: Apple Swift version 5.9 or later
```

If you have multiple Xcode installations, verify the active toolchain:

```bash
xcode-select -p
# Should point to your desired Xcode.app
```

### Gradle Build Fails

**"SDK location not found"**

Create or update `local.properties` in the `android/` directory:

```properties
# local.properties
sdk.dir=/Users/yourname/Library/Android/sdk
```

Or set the `ANDROID_HOME` environment variable:

```bash
export ANDROID_HOME=$HOME/Library/Android/sdk
```

**"Could not resolve com.verygoodopensource:j2v8"**

J2V8 is hosted on JitPack. Verify that `jitpack.io` is in your repositories block in `build.gradle`:

```groovy
// android/build.gradle or settings.gradle
repositories {
    google()
    mavenCentral()
    maven { url 'https://jitpack.io' }
}
```

**"Minimum SDK version 24 required"**

Vue Native Android requires API level 24 (Android 7.0) or higher. Check your `build.gradle.kts`:

```kotlin
android {
    defaultConfig {
        minSdk = 24
        targetSdk = 35
    }
}
```

**Dependency conflicts**

If multiple libraries include conflicting versions of the same dependency, Gradle will fail. Use `./gradlew dependencies` to inspect the dependency tree and resolve conflicts with `exclude` or `force`:

```groovy
configurations.all {
    resolutionStrategy {
        force 'com.squareup.okhttp3:okhttp:4.12.0'
    }
}
```

### Vite Bundle Errors

**"Cannot resolve 'vue'"**

The Vue Native Vite plugin aliases `vue` to `@thelacanians/vue-native-runtime`. Make sure both plugins are in your Vite config:

```ts
// vite.config.ts
import vue from '@vitejs/plugin-vue'
import vueNative from '@thelacanians/vue-native-vite-plugin'

export default defineConfig({
  plugins: [vue(), vueNative()],
})
```

**"Top-level await is not available" or "Dynamic import is not supported"**

JavaScriptCore and V8 (via J2V8) load IIFE bundles, which cannot use top-level await or dynamic imports. The Vite plugin sets `inlineDynamicImports: true` automatically, but your code must not use top-level await:

```ts
// Wrong -- top-level await
const data = await fetchInitialData()

// Correct -- call inside an async function
async function init() {
  const data = await fetchInitialData()
}
init()
```

**"process is not defined"**

The Vite plugin replaces `process.env.NODE_ENV` at build time, but libraries that reference other `process` properties will fail in JavaScriptCore/V8 where `process` does not exist. Add these defines to your Vite config:

```ts
export default defineConfig({
  define: {
    'process.env': '{}',
  },
  plugins: [vue(), vueNative()],
})
```

### `vue-native dev` Not Connecting

The dev server starts a WebSocket on port 8174 by default. If the app cannot connect:

**Check the port is not in use:**

```bash
lsof -i :8174
# If another process is using it, specify a different port:
vue-native dev --port 8175
```

**iOS Simulator:**

The Simulator shares the host network, so `ws://localhost:8174` works directly. Verify the dev server URL in your native code matches.

**Android Emulator:**

The Android emulator maps `10.0.2.2` to the host's `localhost`. Your `VueNativeActivity` must use:

```kotlin
override fun getDevServerUrl(): String? {
    return "ws://10.0.2.2:8174"
}
```

**Physical device:**

The device must be on the same network as your development machine. Use your machine's LAN IP instead of `localhost`:

```
ws://192.168.1.100:8174
```

**Firewall:**

Ensure your OS firewall allows incoming connections on the dev server port. On macOS, you may see a prompt the first time; click "Allow".

## Runtime Issues

### App Crashes on Launch

**Bundle not loading:**

The most common cause is the IIFE bundle not being found at the expected path. Verify:

- **iOS:** The bundle file (`vue-native-bundle.js`) is copied to the app's bundle resources. Check that it appears in Xcode's "Copy Bundle Resources" build phase.
- **Android:** The bundle is in `src/main/assets/` and `getBundleAssetPath()` returns the correct filename.

Run a production build first to generate the bundle:

```bash
bun run vite build
```

**Missing polyfills:**

JavaScriptCore does not provide `setTimeout`, `setInterval`, `console`, `fetch`, or other Web APIs. Vue Native's native runtime injects these polyfills during initialization. If the native setup code runs after the bundle evaluates, these will be missing:

```
TypeError: setTimeout is not a function
```

**Solution:** Ensure `JSRuntime.initialize()` (iOS) or `JSRuntime.initialize(context)` (Android) is called before `evaluateScript()`.

### White Screen

A white screen with no visible error usually means the JavaScript bundle threw before rendering the first frame.

**Debugging steps:**

1. Check the Xcode console or Logcat for error messages prefixed with `[VueNative]`.
2. Try adding `console.log('Bundle loaded')` at the top of your `main.ts` to verify the bundle is executing.
3. Wrap your root component in a try/catch to see if `app.start()` throws:

```ts
try {
  const app = createApp(App)
  app.start()
  console.log('App started successfully')
} catch (e) {
  console.error('Failed to start app:', e)
}
```

4. If you see no console output at all, the bundle may have a syntax error. Run `bun run vite build` and check for Vite errors.

### Hot Reload Not Working

Hot reload depends on three pieces: the Vite watcher, the WebSocket server, and the native `HotReloadManager`.

**Vite not rebuilding:**

Check the terminal where `vue-native dev` is running. You should see `[vite]` output when files change. If not:

- Verify the file you edited is inside the Vite project root.
- Check that `chokidar` can watch the file (some networked file systems do not support file watching).

**WebSocket not connected:**

The dev server logs `Client connected` when the app connects. If you do not see this:

- Verify the app is running and configured to connect to the correct WebSocket URL.
- Check for firewall or network issues (see [vue-native dev Not Connecting](#vue-native-dev-not-connecting)).
- On iOS, confirm `HotReloadManager` is started with the correct URL in `VueNativeViewController`.
- On Android, confirm `getDevServerUrl()` returns the correct URL.

**Bundle sent but app not reloading:**

If the server logs `Bundle updated ... sent to N client(s)` but the app does not refresh:

- Check the native console for errors during `JSRuntime.reload()`.
- The reload process calls `__VN_teardown` to reset bridge state and node IDs, then evaluates the new bundle. If the new bundle has errors, it will fail silently. Add a `console.log` at the top of `main.ts` to verify execution.

### Slow Performance

**Bridge flooding:**

Every style change, prop update, and tree mutation is a bridge operation. If your app sends thousands of operations per frame, performance will degrade. Common causes:

- Animating styles via reactive state changes on every frame instead of using `useAnimation` (which runs animations natively).
- Rendering very long lists without virtualization (use `VList` instead of mapping an array inside `VScrollView`).
- Deeply nested view hierarchies that trigger cascading layout recalculations.

Use `usePerformance` to measure:

```ts
import { usePerformance } from '@thelacanians/vue-native-runtime'

const { fps, bridgeOps, startProfiling, stopProfiling } = usePerformance()

await startProfiling()
// Run the slow operation
setTimeout(async () => {
  console.log('FPS:', fps.value, 'Bridge ops:', bridgeOps.value)
  await stopProfiling()
}, 5000)
```

**Layout thrashing:**

If Yoga recalculates layout on every frame, the app will stutter. Avoid:

- Changing `width`/`height` styles in a `watch` or `watchEffect` without debouncing.
- Using percentage-based dimensions that trigger recalculation when the parent resizes.

### Memory Issues

**Leaked timers:**

`setTimeout` and `setInterval` callbacks persist even after a component unmounts. Always clear them:

```ts
import { onUnmounted } from 'vue'

const timer = setInterval(() => { /* ... */ }, 1000)
onUnmounted(() => clearInterval(timer))
```

**Leaked event listeners:**

Composables that subscribe to global events (via `NativeBridge.onGlobalEvent`) return an unsubscribe function. Call it in `onUnmounted`:

```ts
import { onUnmounted } from 'vue'
import { NativeBridge } from '@thelacanians/vue-native-runtime'

const unsubscribe = NativeBridge.onGlobalEvent('network:change', (payload) => {
  // handle event
})

onUnmounted(() => unsubscribe())
```

::: tip
Vue Native's built-in composables (`useNetwork`, `useAppState`, `useKeyboard`, etc.) handle cleanup automatically in `onUnmounted`. You only need to manage cleanup for custom subscriptions.
:::

**Large images:**

Loading many high-resolution images can exhaust memory. Use `VImage` with appropriate dimensions rather than loading full-resolution images and scaling them down in the layout:

```vue
<!-- Prefer specifying dimensions to prevent full-resolution decode -->
<VImage
  :source="{ uri: imageUrl }"
  :style="{ width: 100, height: 100 }"
/>
```

## Platform-Specific Issues

### iOS Simulator

**"Unable to boot device in current state"**

The simulator may be in an inconsistent state. Reset it:

```bash
xcrun simctl shutdown all
xcrun simctl erase all
```

Or reset a specific simulator:

```bash
xcrun simctl erase <UDID>
```

**Keyboard not appearing in Simulator:**

The hardware keyboard is connected by default. Toggle it: **I/O -> Keyboard -> Connect Hardware Keyboard** (or press Cmd+Shift+K).

**Slow Simulator performance:**

- Close other resource-intensive applications.
- Use a smaller device (iPhone SE instead of iPhone 15 Pro Max).
- Disable animations: **Debug -> Slow Animations** should be unchecked.

### Android Emulator

**"INSTALL_FAILED_NO_MATCHING_ABIS"**

The APK was built for a CPU architecture the emulator does not support. Use an x86_64 emulator image on Intel/AMD machines, or an arm64 image on Apple Silicon.

**Emulator cannot connect to dev server:**

Remember that the Android emulator routes `10.0.2.2` to the host. If using a custom port:

```kotlin
override fun getDevServerUrl(): String? {
    return "ws://10.0.2.2:8175"
}
```

Also ensure you run `adb reverse` if connecting over USB:

```bash
adb reverse tcp:8174 tcp:8174
```

**Emulator running out of memory:**

Increase the emulator's RAM in AVD Manager: **Tools -> Device Manager -> Edit -> Show Advanced Settings -> RAM**.

### Device-Specific Quirks

**iOS notch / Dynamic Island:**

Use `VSafeArea` to inset content away from the notch, home indicator, and Dynamic Island:

```vue
<VSafeArea :style="{ flex: 1 }">
  <VView :style="{ flex: 1, padding: 16 }">
    <!-- Content is safely inset -->
  </VView>
</VSafeArea>
```

**Android back button:**

The hardware/gesture back button requires `useBackHandler` to intercept:

```ts
import { useBackHandler } from '@thelacanians/vue-native-runtime'

useBackHandler(() => {
  // Return true to prevent default back behavior
  if (hasUnsavedChanges.value) {
    showDiscardDialog()
    return true
  }
  return false
})
```

**Android soft keyboard resizing the layout:**

Use `VKeyboardAvoiding` to adjust the layout when the keyboard appears:

```vue
<VKeyboardAvoiding :style="{ flex: 1 }" behavior="padding">
  <VInput placeholder="Type here..." />
</VKeyboardAvoiding>
```

On Android, also ensure `windowSoftInputMode` is set in your `AndroidManifest.xml`:

```xml
<activity
  android:windowSoftInputMode="adjustResize"
  ... />
```

## Getting Help

### Before Filing an Issue

1. **Update to the latest version** of all `@thelacanians/vue-native-*` packages.
2. **Search existing issues** on GitHub -- your problem may already have a solution.
3. **Create a minimal reproduction** -- strip your app down to the smallest code that reproduces the issue.
4. **Include environment details:**

```bash
# Run these and include the output
bun --version
node --version
swift --version
xcode-select -p
```

### Filing a GitHub Issue

Open an issue at [github.com/abdul-hamid-achik/vue-native/issues](https://github.com/abdul-hamid-achik/vue-native/issues) with:

- A clear title describing the problem.
- Steps to reproduce (ideally with a minimal example project).
- Expected behavior vs. actual behavior.
- Your environment (OS, Xcode/Android Studio version, device/simulator).
- Relevant error messages or stack traces.
- Screenshots or screen recordings if the issue is visual.

::: tip
The more specific your reproduction steps, the faster we can diagnose the issue. "It crashes sometimes" is hard to debug. "It crashes when I navigate from Screen A to Screen B after toggling the switch" is actionable.
:::
