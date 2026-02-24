# Error Reporting & Monitoring

This guide covers integrating Vue Native with production error reporting services, monitoring your app in production, and debugging during development. For the foundational error handling APIs (`app.config.errorHandler` and `ErrorBoundary`), see the [Error Handling guide](./error-handling.md).

## How Vue Native's Error System Works

Vue Native has a two-layer error system:

1. **Vue layer** -- `app.config.errorHandler` captures all unhandled errors from components (render functions, lifecycle hooks, event handlers, watchers).
2. **Bridge layer** -- The default error handler serializes the error as JSON and sends it to the native side via `globalThis.__VN_handleError(errorInfo)`, which displays a native error overlay in development.

The flow looks like this:

```
Component throws
  -> onErrorCaptured (ErrorBoundary, if present)
  -> app.config.errorHandler
  -> __VN_handleError (native error overlay / crash reporter)
```

When you set `app.config.errorHandler`, you replace the default handler that Vue Native installs. To preserve the native error overlay in development while adding your own reporting, call `__VN_handleError` yourself:

```ts
import { createApp } from '@thelacanians/vue-native-runtime'
import App from './App.vue'

const app = createApp(App)

// Save the default handler before overriding
const defaultHandler = app.config.errorHandler

app.config.errorHandler = (err, instance, info) => {
  // Your custom reporting logic
  sendToErrorService(err, instance, info)

  // Preserve the default behavior (native error overlay in dev)
  if (defaultHandler) {
    defaultHandler(err, instance, info)
  }
}

app.start()
```

## Setting Up Error Reporting

### Sentry

[Sentry](https://sentry.io) is a widely used error monitoring service. Since Vue Native runs JavaScript in JavaScriptCore (iOS) or V8 (Android), you cannot use Sentry's browser SDK directly. Instead, capture errors manually and send them via `useHttp`.

```ts
// services/sentry.ts
import { useHttp } from '@thelacanians/vue-native-runtime'

const SENTRY_DSN = 'https://examplePublicKey@o0.ingest.sentry.io/0'

// Parse DSN into its components
function parseDSN(dsn: string) {
  const match = dsn.match(/^https:\/\/(.+?)@(.+?)\/(.+)$/)
  if (!match) throw new Error('Invalid Sentry DSN')
  return { publicKey: match[1], host: match[2], projectId: match[3] }
}

export function createSentryReporter() {
  const { publicKey, host, projectId } = parseDSN(SENTRY_DSN)
  const http = useHttp({
    baseURL: `https://${host}`,
    headers: {
      'Content-Type': 'application/json',
      'X-Sentry-Auth': `Sentry sentry_version=7, sentry_key=${publicKey}`,
    },
  })

  return {
    captureException(err: Error, context?: Record<string, any>) {
      const payload = {
        event_id: generateUUID(),
        timestamp: new Date().toISOString(),
        platform: 'javascript',
        exception: {
          values: [{
            type: err.name,
            value: err.message,
            stacktrace: { frames: parseStack(err.stack) },
          }],
        },
        tags: context,
      }

      http.post(`/api/${projectId}/store/`, payload).catch((e) => {
        console.warn('[Sentry] Failed to send event:', e.message)
      })
    },
  }
}

function generateUUID(): string {
  return 'xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = Math.random() * 16 | 0
    return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16)
  })
}

function parseStack(stack?: string) {
  if (!stack) return []
  return stack.split('\n').slice(1).map((line) => {
    const match = line.match(/at\s+(.+?)\s+\((.+?):(\d+):(\d+)\)/)
    if (!match) return { filename: 'unknown', function: line.trim() }
    return {
      function: match[1],
      filename: match[2],
      lineno: parseInt(match[3]),
      colno: parseInt(match[4]),
    }
  })
}
```

### Bugsnag

```ts
// services/bugsnag.ts
import { useHttp } from '@thelacanians/vue-native-runtime'

const BUGSNAG_API_KEY = 'your-api-key'

export function createBugsnagReporter() {
  const http = useHttp({
    baseURL: 'https://notify.bugsnag.com',
    headers: {
      'Bugsnag-Api-Key': BUGSNAG_API_KEY,
      'Bugsnag-Payload-Version': '5',
    },
  })

  return {
    notify(err: Error, context?: Record<string, any>) {
      const payload = {
        apiKey: BUGSNAG_API_KEY,
        payloadVersion: '5',
        notifier: { name: 'vue-native', version: '1.0.0' },
        events: [{
          exceptions: [{
            errorClass: err.name,
            message: err.message,
            stacktrace: err.stack,
          }],
          metaData: context,
        }],
      }

      http.post('/', payload).catch((e) => {
        console.warn('[Bugsnag] Failed to send event:', e.message)
      })
    },
  }
}
```

### Custom Backend Endpoint

If you run your own error tracking service, the pattern is straightforward:

```ts
// services/errorReporter.ts
import { useHttp } from '@thelacanians/vue-native-runtime'
import { useDeviceInfo, usePlatform } from '@thelacanians/vue-native-runtime'

export function createErrorReporter(endpoint: string, apiKey: string) {
  const http = useHttp({
    baseURL: endpoint,
    headers: { Authorization: `Bearer ${apiKey}` },
  })

  return {
    async report(err: Error, context?: Record<string, any>) {
      const device = useDeviceInfo()
      const { platform } = usePlatform()

      const payload = {
        timestamp: Date.now(),
        error: {
          name: err.name,
          message: err.message,
          stack: err.stack,
        },
        device: {
          platform: platform.value,
          model: device.model.value,
          osVersion: device.osVersion.value,
        },
        context,
      }

      try {
        await http.post('/errors', payload)
      } catch (e) {
        // Avoid infinite loops -- do NOT throw from error reporter
        console.warn('[ErrorReporter] Failed to send:', (e as Error).message)
      }
    },
  }
}
```

## Production Error Monitoring

### Complete Setup Example

Wire everything together in your app's entry point:

```ts
// main.ts
import { createApp } from '@thelacanians/vue-native-runtime'
import App from './App.vue'
import { createErrorReporter } from './services/errorReporter'

const app = createApp(App)

// Create the reporter outside the error handler
// (useHttp must be called in a setup context or at module scope)
const reporter = createErrorReporter(
  'https://errors.myapp.com',
  'my-api-key'
)

// Save the built-in handler that sends to __VN_handleError
const builtInHandler = app.config.errorHandler

app.config.errorHandler = (err, instance, info) => {
  const error = err instanceof Error ? err : new Error(String(err))
  const componentName = instance?.$options?.name || 'Anonymous'

  // 1. Send to your error service
  reporter.report(error, {
    componentName,
    lifecycleHook: info,
    route: getCurrentRoute(), // if using navigation
  })

  // 2. Preserve the built-in handler (native error overlay in dev)
  if (builtInHandler) {
    builtInHandler(err, instance, info)
  }
}

app.start()
```

### Using ErrorBoundary for Graceful Degradation

Wrap critical sections with `ErrorBoundary` to show fallback UI instead of crashing. The `onError` prop is the right place to report boundary-level errors:

```vue
<script setup>
import { ErrorBoundary, VView, VText, VButton } from '@thelacanians/vue-native-runtime'
import { reporter } from './services/errorReporter'

function onFeedError(error, info) {
  reporter.report(error, { section: 'feed', info })
}
</script>

<template>
  <VView :style="{ flex: 1 }">
    <ErrorBoundary :onError="onFeedError">
      <template #default>
        <NewsFeed />
      </template>
      <template #fallback="{ error, reset }">
        <VView :style="{ padding: 20, alignItems: 'center' }">
          <VText :style="{ fontSize: 16, marginBottom: 12 }">
            Unable to load feed
          </VText>
          <VButton
            :onPress="reset"
            :style="{ padding: 10, backgroundColor: '#007AFF', borderRadius: 8 }"
          >
            <VText :style="{ color: '#fff' }">Retry</VText>
          </VButton>
        </VView>
      </template>
    </ErrorBoundary>
  </VView>
</template>
```

::: tip
The global `app.config.errorHandler` does NOT fire for errors caught by `ErrorBoundary` because the boundary returns `false` from `onErrorCaptured`, which stops propagation. Always add reporting logic in the boundary's `onError` prop too.
:::

### Native Crash Reporting

JavaScript errors are caught by the Vue error handler. But native-side crashes (Swift/Kotlin exceptions, memory exhaustion, segfaults) require native crash reporting tools:

**iOS:**
- **Xcode Organizer** -- View crash logs from TestFlight and App Store users.
- **Firebase Crashlytics** -- Add the Crashlytics SDK to your Xcode project for real-time crash reporting. Crashlytics captures Swift/ObjC exceptions and C-level signals automatically.
- **MetricKit** -- Apple's first-party framework for crash diagnostics and performance metrics on iOS 14+.

**Android:**
- **Firebase Crashlytics** -- Add the Gradle plugin and SDK. Captures Java/Kotlin exceptions, ANRs, and native (NDK) crashes.
- **Google Play Console** -- Android Vitals shows crash rate, ANR rate, and device-specific issues.

Native crash reporters complement JavaScript error handling. Use both together for complete coverage.

### Performance-Aware Error Monitoring

Use `usePerformance` to correlate errors with performance metrics:

```ts
import { usePerformance } from '@thelacanians/vue-native-runtime'

const { fps, memoryMB, bridgeOps, startProfiling } = usePerformance()

// Include performance data in error reports
function reportWithMetrics(error: Error, context?: Record<string, any>) {
  reporter.report(error, {
    ...context,
    fps: fps.value,
    memoryMB: memoryMB.value,
    bridgeOps: bridgeOps.value,
  })
}
```

## Debugging in Development

### Console Logging

Vue Native provides `console.log`, `console.warn`, `console.error`, and `console.debug` via polyfills injected into the JavaScript runtime. These output to:

- **iOS** -- Xcode's Debug Console (visible when the app is launched from Xcode).
- **Android** -- Logcat (filter by `VueNative` tag in Android Studio).

```ts
console.log('Regular log')         // Informational
console.warn('Something odd')      // Yellow in Xcode, WARN in Logcat
console.error('Something broke')   // Red in Xcode, ERROR in Logcat
```

::: warning
`console.log` with large objects (deeply nested reactive proxies, large arrays) can freeze the app because the entire object is serialized to JSON for the bridge. Log only the specific values you need.
:::

### Error Overlay

In development mode (`__DEV__ === true`), Vue Native's built-in error handler sends error details to the native side via `__VN_handleError`. The native layer displays an error overlay showing:

- The error message
- The component name where it occurred
- The lifecycle hook or source (e.g., "render function", "setup function")
- A stack trace

The overlay appears automatically. Tap it to dismiss.

### Hot Reload for Quick Iteration

The `vue-native dev` command starts a Vite watch-mode build and a WebSocket server on port 8174 (configurable with `--port`). When you save a file:

1. Vite rebuilds the IIFE bundle.
2. Chokidar detects the bundle file change.
3. The dev server broadcasts the new bundle to all connected clients via WebSocket.
4. The native `HotReloadManager` receives the bundle and calls `JSRuntime.reload()`, which tears down the old JS context and evaluates the new bundle.

If hot reload is not picking up your changes, see the [Troubleshooting guide](./troubleshooting.md#hot-reload-not-working).

### Source Maps

In development builds, Vite generates source maps alongside the IIFE bundle (`vue-native-bundle.js.map`). This means stack traces in error messages map back to your original `.vue` and `.ts` files rather than the bundled output.

Source maps are enabled automatically when running `vue-native dev` or building with `--mode development`. They are disabled in production builds to reduce bundle size.

::: tip
When reading a stack trace, look for your source file names (e.g., `App.vue`, `HomeScreen.vue`). If you only see references to `vue-native-bundle.js`, source maps may not be loading -- verify that the `.map` file exists next to the bundle.
:::

## Common Errors & Solutions

### "Module not found" or "__VN_flushOperations is not registered"

**Cause:** The native runtime has not initialized its bridge functions before the JavaScript bundle is evaluated. This can happen when:
- The Swift/Kotlin native setup code runs after the bundle loads.
- A native module is invoked before it is registered.

**Solution:**
```
// The bridge warns when __VN_flushOperations is missing:
// "[VueNative] __VN_flushOperations is not registered.
//  Make sure the native runtime has been initialized."

// Verify your native entry point registers polyfills BEFORE evaluating the bundle.
// iOS: JSRuntime.initialize() must call registerPolyfills() first.
// Android: VueNativeActivity.onCreate() must call JSRuntime.initialize() first.
```

### "Cannot read property of undefined"

**Common causes:**
- Accessing a ref without `.value` (e.g., `count` instead of `count.value` in script).
- Using a composable outside of `setup()` or `<script setup>`.
- Accessing data from an async call before it resolves.

**Solutions:**
```ts
// Wrong -- accessing ref without .value in script
const count = ref(0)
console.log(count) // Ref object, not the value

// Correct
console.log(count.value) // 0

// Wrong -- composable outside setup
const http = useHttp() // Must be inside setup()

// Correct
export default defineComponent({
  setup() {
    const http = useHttp()
    return { http }
  },
})
```

### Bridge Timeout Errors

**Message:** `[VueNative] Native module <Module>.<method> timed out after 30000ms`

**Cause:** The native module did not respond to an async invocation within 30 seconds. The bridge uses `invokeNativeModule` which registers a callback and waits for the native side to call `__VN_resolveCallback` with the matching callback ID.

**Common reasons:**
- The native module is not registered.
- The native method threw an exception before resolving the callback.
- A long-running native operation (camera capture, file I/O) genuinely takes too long.

**Solutions:**
```ts
// Increase timeout for long-running operations
import { NativeBridge } from '@thelacanians/vue-native-runtime'

// Default is 30 seconds; increase for heavy operations
const result = await NativeBridge.invokeNativeModule(
  'FileSystem',
  'downloadLargeFile',
  [url],
  120_000, // 2 minutes
)
```

```ts
// Always handle timeout errors gracefully
try {
  const photo = await camera.takePhoto({ quality: 'high' })
} catch (err) {
  if (err.message.includes('timed out')) {
    console.warn('Camera operation timed out, retrying...')
  }
}
```

### Layout Issues

**Symptoms:** Views not appearing, incorrect sizing, overlapping elements.

**Debugging tips:**

1. **Add a background color** to suspect views to see their actual frame:
```vue
<VView :style="{ backgroundColor: 'rgba(255,0,0,0.2)', flex: 1 }">
  <VText>Is this visible?</VText>
</VView>
```

2. **Check `flex: 1`** -- Most layout issues stem from missing `flex: 1` on parent containers. The root view and intermediate containers need it:
```vue
<!-- Wrong: VText may not appear -->
<VView>
  <VText>Hello</VText>
</VView>

<!-- Correct: flex: 1 gives the view dimensions -->
<VView :style="{ flex: 1 }">
  <VText>Hello</VText>
</VView>
```

3. **Verify flex direction** -- The default flex direction is `column` (top to bottom). If items should be side by side, set `flexDirection: 'row'`.

4. **Text measurement** -- If `VText` content is truncated or overlapping, the Yoga layout engine may not have correct text measurements. Ensure you set `fontSize` explicitly rather than relying on defaults.

::: warning
Do not mix Yoga-based layout (Vue Native styles) with native AutoLayout constraints in the same view hierarchy. They use different layout engines and will produce unpredictable results.
:::

### Callback Queue Full

**Message:** `Callback queue full, evicting oldest pending callback`

**Cause:** More than 1,000 async native module calls are pending simultaneously. This typically indicates a loop or rapid-fire calls that outpace native responses.

**Solution:** Debounce or throttle native module calls, and verify that native modules are actually resolving their callbacks.
