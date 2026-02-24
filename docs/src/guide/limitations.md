# Known Limitations & Platform Differences

Vue Native renders to **native UIKit views** (iOS) and **Android Views** (Android), not to a WebView. JavaScript runs inside JavaScriptCore (iOS) and J2V8/V8 (Android) -- environments that provide no browser APIs. This page documents what is available, what is not, and where the two platforms diverge.

## No DOM

There is no `document`, no `window`, no `navigator`, and no HTML element tree. Any code that references browser globals will throw a `ReferenceError` at runtime.

| Browser API | Vue Native Replacement |
|---|---|
| `document.getElementById()` | Use `ref` on a component and the bridge node system |
| `window.addEventListener()` | `useAppState`, `useKeyboard`, `useDimensions` |
| `localStorage` / `sessionStorage` | `useAsyncStorage` (key-value) or `useSecureStorage` (encrypted) |
| `window.location` | `useRouter` and `useLinking` |
| `window.fetch` | Polyfilled -- works as expected (backed by `URLSession` / `OkHttp`) |
| `alert()` / `confirm()` | `VAlertDialog` / `VActionSheet` components |
| `navigator.clipboard` | `useClipboard` |
| `navigator.geolocation` | `useGeolocation` |
| `navigator.vibrate` | `useHaptics` |

::: danger
Libraries that access `document` or `window` at import time will crash the app during bundle evaluation, before any component renders. Always verify third-party libraries in a native build, not just in a web browser.
:::

## CSS Limitations

Vue Native uses **Yoga** (iOS, via FlexLayout) and **FlexboxLayout** (Android) for layout. This is a subset of CSS Flexbox, not the full CSS specification.

### Supported Layout Properties

All standard Flexbox properties are available: `flex`, `flexDirection`, `flexWrap`, `alignItems`, `alignSelf`, `justifyContent`, `alignContent`, `flexGrow`, `flexShrink`, `flexBasis`, `gap`, `rowGap`, `columnGap`.

Box model properties are supported: `width`, `height`, `minWidth`, `maxWidth`, `minHeight`, `maxHeight`, `padding`, `margin`, `borderWidth`. Percentage values work for dimensions and padding/margin.

See the [Styling guide](./styling.md) for the full property reference.

### Not Supported

| CSS Feature | Status | Workaround |
|---|---|---|
| CSS Grid | Not available | Use nested Flexbox containers |
| `float` | Not available | Use `flexDirection: 'row'` |
| `position: fixed` | Not available | Use `position: 'absolute'` inside a flex container |
| `z-index` stacking contexts | Not available | Control rendering order by component tree order (later siblings render on top) |
| CSS transitions / `@keyframes` | Not available | Use `useAnimation` (runs natively) |
| Media queries | Not available | Use `useDimensions` to read screen size reactively |
| Pseudo-classes (`:hover`, `:focus`) | Not available | Use `VPressable` with press state callbacks |
| `box-shadow` | iOS only (`shadowColor`, `shadowOffset`, `shadowOpacity`, `shadowRadius`) | Use `elevation` on Android |
| `transform` (CSS syntax) | Not available | Use `useAnimation` with `translateX`, `translateY`, `scale`, `rotate` |
| `overflow: scroll` | Not available | Use `VScrollView` or `VList` |
| CSS variables / `calc()` | Not available | Compute values in JavaScript |
| `display: none` | Not available | Use `v-if` to remove or `v-show` (sets `opacity: 0` + disables interaction) |

::: tip
Think of styling in Vue Native as "Flexbox plus appearance properties." If a CSS feature requires the browser's layout engine or CSSOM, it will not work here.
:::

## JavaScript Environment

Bundles are compiled to **IIFE format** targeting **ES2020**. There is no ESM `import()` at runtime -- all code is bundled into a single file by Vite.

### Polyfilled APIs (Available)

These APIs are injected by the native runtime before the bundle executes:

- `setTimeout` / `clearTimeout`
- `setInterval` / `clearInterval`
- `queueMicrotask`
- `requestAnimationFrame` / `cancelAnimationFrame`
- `console` (log, warn, error, info, debug)
- `fetch` / `Request` / `Response` / `Headers`
- `Promise` (native in JSC/V8)
- `URL` / `URLSearchParams`
- `TextEncoder` / `TextDecoder`
- `atob` / `btoa`
- `crypto.getRandomValues`
- `performance.now()`
- `globalThis`

### Not Available

| API | Reason |
|---|---|
| Web Workers / `SharedWorker` | Single JS thread; no worker runtime |
| `IndexedDB` | Browser storage API; use `useDatabase` for SQLite |
| Service Workers | No browser registration model |
| WebGL / Canvas API | No `<canvas>` element; use `VImage` for graphics |
| `WebAssembly` | Not exposed in JSC/J2V8 by default |
| `MutationObserver` | No DOM to observe |
| `ResizeObserver` / `IntersectionObserver` | No DOM; use `useDimensions` or `VList` visibility callbacks |
| `XMLHttpRequest` | Use `fetch` or `useHttp` instead |
| `Blob` / `File` | Use `useFileSystem` for file operations |
| `EventSource` (SSE) | Use `useWebSocket` for real-time connections |

::: warning
Top-level `await` is not supported in IIFE bundles. Wrap async initialization inside an `async function` and call it.
:::

## Third-Party Library Compatibility

### Libraries That Work

Any **pure JavaScript** library with no DOM or Node.js dependencies works out of the box:

- **Utilities:** lodash, ramda, date-fns, dayjs
- **Validation:** zod, yup, valibot, joi
- **State:** pinia (with Vue Native's Vue instance), zustand (vanilla store)
- **Data:** uuid, nanoid, immer, superjson
- **Parsing:** papaparse, yaml, toml
- **Math/crypto:** bignumber.js, tweetnacl

### Libraries That Do Not Work

Any library that imports or accesses browser APIs at the module level will fail:

- **React ecosystem:** react, react-dom, and all React component libraries
- **DOM manipulation:** jQuery, cheerio (server-only OK), D3 (rendering parts)
- **CSS-in-JS:** styled-components, emotion, tailwind (runtime), stitches
- **Browser routing:** vue-router (web version) -- use `@thelacanians/vue-native-navigation`
- **Canvas/WebGL:** three.js, PixiJS, chart.js, p5.js

### Libraries Needing Adaptation

| Library | Issue | Use Instead |
|---|---|---|
| axios | Uses `XMLHttpRequest` internally | `useHttp` (built-in, native networking) |
| socket.io-client | Depends on browser WebSocket + polling | `useWebSocket` (native implementation) |
| vue-router | Depends on browser History API | `@thelacanians/vue-native-navigation` |
| async-storage (React Native) | Different bridge protocol | `useAsyncStorage` (built-in) |

## Platform Differences (iOS vs Android)

While Vue Native abstracts most platform details, certain behaviors differ between iOS and Android.

### Keyboard Handling

| Behavior | iOS | Android |
|---|---|---|
| Default resize behavior | Content pushed up automatically | Requires `android:windowSoftInputMode="adjustResize"` in manifest |
| `VKeyboardAvoiding` behavior prop | `"padding"` (recommended) | `"padding"` or `"height"` |
| Keyboard dismiss | Tap outside input | Back button or tap outside |

### Status Bar

| Behavior | iOS | Android |
|---|---|---|
| Light/dark text | `VStatusBar barStyle="light-content"` | Same API, but may require `android:windowLightStatusBar` |
| Translucent | Translucent by default | Must set `translucent={true}` explicitly |
| Background color | Not directly settable (use `VView` behind it) | Settable via `backgroundColor` prop |

### Safe Areas & Notch

- **iOS:** `VSafeArea` insets for notch, Dynamic Island, and home indicator.
- **Android:** `VSafeArea` insets for status bar and navigation bar. Cutout (notch) handling depends on `android:windowLayoutInDisplayCutoutMode`.

### Back Navigation

- **iOS:** Swipe-from-left-edge gesture is handled automatically by the stack navigator.
- **Android:** Hardware/gesture back button must be intercepted with `useBackHandler`. The stack navigator handles this by default, but custom back logic requires explicit handling.

### Shadows

- **iOS:** Uses `shadowColor`, `shadowOffset`, `shadowOpacity`, `shadowRadius` (Core Animation).
- **Android:** Uses `elevation` (Material Design shadow). The four iOS shadow properties are ignored on Android.

### Permissions

- **iOS:** Permissions are requested via system dialogs. Denied permissions can only be changed in Settings. The `Info.plist` must include usage description strings.
- **Android:** Permissions use the runtime permission model (API 23+). Denied permissions can be re-requested unless "Don't ask again" was selected. The `AndroidManifest.xml` must declare permissions.

## Performance Boundaries

Vue Native is designed for typical mobile app workloads. Be aware of these practical limits:

| Scenario | Guideline |
|---|---|
| `VList` items | Handles up to ~500 items smoothly. Beyond 1,000 items, use pagination or incremental loading. |
| View tree depth | Keep below 10-15 levels of nesting. Deeply nested trees increase layout calculation time. |
| Total native nodes | Apps with 10,000+ simultaneous nodes may see increased memory pressure. Unmount screens and use `VList` virtualization. |
| Heavy computation | All JS runs on a single thread. Computations over ~16ms block the frame. Break large work into chunks with `setTimeout` or `requestAnimationFrame`. |
| Bridge operations | Vue Native batches bridge calls per microtask, but thousands of prop updates in a single tick will stall rendering. Use `useAnimation` for frame-by-frame visual changes. |
| Images | High-resolution images consume significant memory. Size images appropriately and avoid loading dozens of full-resolution images simultaneously. |

::: tip
Use `usePerformance` to profile your app. Watch for FPS drops below 55, steadily growing memory, or bridge operation spikes. See the [Performance guide](./performance.md) for details.
:::

## Navigation Limitations

Vue Native navigation is a **native stack** managed in JavaScript -- not browser history.

- There is no URL bar, no `<a>` tags, and no `window.history`.
- Use `useRouter().push()`, `pop()`, `replace()`, and `reset()` for all navigation.
- Deep linking is supported via `useLinking` and the router's `linking` config, but the URL is parsed and mapped to a route -- there is no browser navigation happening.
- The browser-based `vue-router` package is not compatible. Use `@thelacanians/vue-native-navigation`.
- Tab and drawer navigators maintain their own stacks. Nested navigators are supported but add complexity; keep nesting to two levels when possible.

::: warning
Calling `router.reset()` destroys the entire navigation stack and rebuilds it. Use it only for flows like sign-out where you need to clear all screen state.
:::
