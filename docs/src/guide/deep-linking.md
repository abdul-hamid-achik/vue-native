# Deep Linking & Universal Links

Deep linking allows external URLs to open specific screens inside your Vue Native app. This guide covers custom URL schemes, Universal Links (iOS), App Links (Android), and how to integrate them with the Vue Native navigation router.

## URL Schemes (Custom)

A custom URL scheme lets your app respond to URLs like `myapp://profile/123`. Both iOS and Android require explicit configuration.

### iOS Configuration

Add your custom scheme to `Info.plist` under `CFBundleURLTypes`:

```xml
<!-- ios/MyApp/Info.plist -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>myapp</string>
    </array>
    <key>CFBundleURLName</key>
    <string>com.example.myapp</string>
  </dict>
</array>
```

Then wire your `SceneDelegate` to pass the URL to `LinkingModule.initialURL` so the JavaScript layer can read it on launch:

```swift
// SceneDelegate.swift
import UIKit
import VueNativeCore

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Capture the URL that launched the app (cold start)
        if let url = connectionOptions.urlContexts.first?.url {
            LinkingModule.initialURL = url.absoluteString
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = MyAppViewController()
        window.makeKeyAndVisible()
        self.window = window
    }

    // Handle URLs while the app is already running (warm start)
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        NativeBridge.shared.emitGlobalEvent("url", payload: ["url": url.absoluteString])
    }
}
```

::: tip
`LinkingModule.initialURL` is a static property. Set it **before** the JS bundle loads so that `getInitialURL` returns the correct value when the router initializes.
:::

### Android Configuration

Add an intent filter to your launcher activity in `AndroidManifest.xml`:

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<activity
    android:name=".MainActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="myapp" />
    </intent-filter>
</activity>
```

`VueNativeActivity` automatically reads `intent.data` on launch and sets it as the `initialURL` on the `LinkingModule`:

```kotlin
// Handled automatically inside VueNativeActivity.onCreate:
intent?.data?.toString()?.let { url ->
    val linkingModule = NativeModuleRegistry.getInstance(this)
        .getModule("Linking") as? LinkingModule
    linkingModule?.initialURL = url
}
```

To handle URLs arriving while the Activity is already running, override `onNewIntent`:

```kotlin
override fun onNewIntent(intent: Intent?) {
    super.onNewIntent(intent)
    intent?.data?.toString()?.let { url ->
        bridge.emitGlobalEvent("url", mapOf("url" to url))
    }
}
```

## Universal Links (iOS) / App Links (Android)

Unlike custom URL schemes, Universal Links and App Links use standard `https://` URLs. They require server-side verification to prove you own the domain.

### Universal Links (iOS)

**1. Enable Associated Domains in Xcode:**

In your app target under **Signing & Capabilities**, add the Associated Domains capability and add an entry:

```
applinks:example.com
```

**2. Host the apple-app-site-association file:**

Serve the following JSON at `https://example.com/.well-known/apple-app-site-association` (no file extension, `Content-Type: application/json`):

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.example.myapp",
        "paths": ["/profile/*", "/settings"]
      }
    ]
  }
}
```

Replace `TEAMID` with your Apple Developer Team ID.

**3. Handle in SceneDelegate:**

```swift
func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL else { return }
    NativeBridge.shared.emitGlobalEvent("url", payload: ["url": url.absoluteString])
}
```

### App Links (Android)

**1. Add intent filter with auto-verify:**

```xml
<activity android:name=".MainActivity" android:exported="true">
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data
            android:scheme="https"
            android:host="example.com"
            android:pathPrefix="/profile" />
    </intent-filter>
</activity>
```

**2. Host the assetlinks.json file:**

Serve the following JSON at `https://example.com/.well-known/assetlinks.json`:

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.example.myapp",
    "sha256_cert_fingerprints": [
      "AB:CD:EF:... (your signing certificate SHA-256)"
    ]
  }
}]
```

Get your certificate fingerprint with:

```bash
keytool -list -v -keystore my-release-key.keystore
```

**3. Verify link association:**

After deploying, verify on the device:

```bash
# Android
adb shell am start -a android.intent.action.VIEW \
  -d "https://example.com/profile/123" com.example.myapp

# iOS — test from Safari or Notes app by tapping a link
```

::: warning
Universal Links and App Links only work with `https://` URLs. They will not fire if the user types the URL directly into the browser address bar -- the link must be tapped from another app or a web page.
:::

## Navigation Integration

The Vue Native router has built-in support for deep links through the `linking` configuration option in `createRouter()`.

### Linking Configuration

The `LinkingConfig` interface accepts two properties:

```ts
interface LinkingConfig {
  prefixes: string[]
  config: { screens: Record<string, string> }
}
```

- **`prefixes`** -- URL prefixes to strip before matching. Include your custom scheme and any Universal Link / App Link domains.
- **`config.screens`** -- A map of screen names to URL path patterns. Use `:param` for dynamic segments.

### Full Example

```ts
import { createApp } from '@thelacanians/vue-native-runtime'
import { createRouter } from '@thelacanians/vue-native-navigation'
import App from './App.vue'
import Home from './screens/Home.vue'
import Profile from './screens/Profile.vue'
import Settings from './screens/Settings.vue'

const router = createRouter({
  routes: [
    { name: 'home', component: Home },
    { name: 'profile', component: Profile },
    { name: 'settings', component: Settings },
  ],
  linking: {
    prefixes: [
      'myapp://',                  // Custom URL scheme
      'https://example.com/',      // Universal Links / App Links
    ],
    config: {
      screens: {
        home: '',                  // myapp:// or https://example.com/
        profile: 'profile/:id',   // myapp://profile/123
        settings: 'settings',     // myapp://settings
      },
    },
  },
})

createApp(App).use(router).start()
```

### How URL Matching Works

When a URL arrives, the router's `handleURL()` method processes it in three steps:

1. **Strip prefix** -- The URL is compared against each entry in `prefixes`. The first matching prefix is removed.
2. **Normalize path** -- Leading and trailing slashes are stripped from the remaining path.
3. **Match screen pattern** -- Each entry in `config.screens` is compared segment by segment. Segments beginning with `:` become named params; literal segments must match exactly.

For example, given the URL `myapp://profile/42`:

| Step | Value |
|------|-------|
| Input URL | `myapp://profile/42` |
| After prefix strip | `profile/42` |
| Pattern | `profile/:id` |
| Result | Navigate to `profile` with `{ id: '42' }` |

::: tip
All params extracted from the URL are strings. If you need a number, convert it in your component: `const id = Number(route.value.params.id)`.
:::

### Handling URLs with `handleURL()`

The router also exposes `handleURL()` directly if you need to programmatically trigger deep link navigation:

```ts
import { useRouter } from '@thelacanians/vue-native-navigation'

const router = useRouter()

// Returns true if the URL matched a screen, false otherwise
const handled = router.handleURL('myapp://profile/42')
```

### Automatic URL Handling

When you provide a `linking` config, the router automatically:

1. **On app launch** -- Calls `getInitialURL` via the native `Linking` module. If the app was opened by a URL, it navigates to the matching screen.
2. **While running** -- Listens for the `url` global event (emitted by the native side when a new URL arrives) and calls `handleURL()`.

You do not need to set up any listeners manually -- this is handled internally by `createRouter()`:

```ts
// This happens automatically inside createRouter() when linking is configured:
NativeBridge.invokeNativeModule('Linking', 'getInitialURL', [])
  .then((url) => { if (url) handleURL(url) })

NativeBridge.onGlobalEvent('url', (payload) => {
  if (payload?.url) handleURL(payload.url)
})
```

## JavaScript Usage

### The `useLinking()` Composable

The `useLinking()` composable provides utilities for opening external URLs and checking URL scheme support. It is separate from the router's deep link handling.

```vue
<script setup>
import { useLinking } from '@thelacanians/vue-native-runtime'

const { openURL, canOpenURL } = useLinking()

async function openProfile() {
  // Open another app via its custom scheme
  const canOpen = await canOpenURL('twitter://user?screen_name=vuejs')
  if (canOpen) {
    await openURL('twitter://user?screen_name=vuejs')
  } else {
    // Fall back to web URL
    await openURL('https://twitter.com/vuejs')
  }
}
</script>
```

| Method | Return Type | Description |
|--------|-------------|-------------|
| `openURL(url)` | `Promise<void>` | Open a URL using the system handler |
| `canOpenURL(url)` | `Promise<boolean>` | Check if a handler is registered for the URL scheme |

::: warning
On iOS, `canOpenURL` requires the queried URL scheme to be listed in `LSApplicationQueriesSchemes` in your `Info.plist`. Without this entry, it returns `false` even if the target app is installed.
:::

### Complete Example: Profile Deep Link

This example shows a complete deep-linking flow where `myapp://profile/123` navigates to a profile screen displaying user data.

**Router setup (main.ts):**

```ts
import { createApp } from '@thelacanians/vue-native-runtime'
import { createRouter } from '@thelacanians/vue-native-navigation'
import App from './App.vue'
import Home from './screens/Home.vue'
import Profile from './screens/Profile.vue'

const router = createRouter({
  routes: [
    { name: 'home', component: Home },
    { name: 'profile', component: Profile },
  ],
  linking: {
    prefixes: ['myapp://', 'https://example.com/'],
    config: {
      screens: {
        home: '',
        profile: 'profile/:id',
      },
    },
  },
})

createApp(App).use(router).start()
```

**Profile screen (screens/Profile.vue):**

```vue
<script setup>
import { ref, watchEffect } from '@thelacanians/vue-native-runtime'
import { useRoute } from '@thelacanians/vue-native-navigation'
import { useHttp } from '@thelacanians/vue-native-runtime'

const route = useRoute()
const { request } = useHttp()
const user = ref(null)

watchEffect(async () => {
  const id = route.value.params.id
  if (id) {
    const response = await request(`https://api.example.com/users/${id}`)
    user.value = response.data
  }
})
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VText :style="{ fontSize: 24, fontWeight: 'bold' }">
      {{ user?.name ?? 'Loading...' }}
    </VText>
    <VText :style="{ fontSize: 16, color: '#666', marginTop: 8 }">
      {{ user?.bio ?? '' }}
    </VText>
  </VView>
</template>
```

**Testing deep links during development:**

```bash
# iOS Simulator
xcrun simctl openurl booted "myapp://profile/123"

# Android Emulator
adb shell am start -a android.intent.action.VIEW \
  -d "myapp://profile/123" com.example.myapp
```

## See Also

- [useLinking composable reference](/composables/useLinking.md)
- [Navigation guide](/guide/navigation.md)
- [Navigation guards](/navigation/guards.md)
