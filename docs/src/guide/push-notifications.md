# Push Notifications

This guide covers the end-to-end setup required to receive remote push notifications in a Vue Native app. It bridges the gap between the [`useNotifications`](/composables/useNotifications.md) composable API and the platform-specific wiring that must happen in your native project.

## How It Works

Push notifications in Vue Native flow through three layers:

1. **Platform registration** -- Your iOS AppDelegate or Android FirebaseMessagingService receives device tokens and incoming push payloads from the OS.
2. **Native module** -- `NotificationsModule` (Swift/Kotlin) caches the device token and dispatches global events (`push:token`, `push:received`, `push:error`) over the bridge.
3. **JavaScript composable** -- `useNotifications()` listens for those global events and exposes them as reactive state and callback hooks.

```
APNs / FCM
   |
   v
AppDelegate / FirebaseMessagingService
   |
   v
NotificationsModule (native)
   |  dispatchGlobalEvent("push:token", ...)
   |  dispatchGlobalEvent("push:received", ...)
   v
NativeBridge --> JS global event bus
   |
   v
useNotifications()  (your Vue component)
```

Because the OS delivers push tokens and payloads to native lifecycle methods that exist *outside* the Vue Native runtime, you must wire those methods yourself. The sections below show exactly what to add for each platform.

## iOS Setup

### 1. Enable the Push Notifications Capability

In Xcode:

1. Select your app target.
2. Go to **Signing & Capabilities**.
3. Click **+ Capability** and add **Push Notifications**.
4. If you plan to do background processing of notifications, also add **Background Modes** and check **Remote notifications**.

This adds the `aps-environment` entitlement to your app, which is required for APNs registration.

### 2. Wire AppDelegate Methods

Your `AppDelegate` (or `SceneDelegate`) must forward three UIApplication callbacks to `NotificationsModule`. The module uses these to cache the device token and dispatch events to JavaScript.

```swift
import UIKit
import VueNativeCore

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    /// Store a reference to the notifications module so we can forward
    /// token and push events from the AppDelegate lifecycle methods.
    private var notificationsModule: NotificationsModule?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // After the bridge initializes, grab a reference to NotificationsModule.
        // NativeModuleRegistry.shared registers it during NativeBridge.shared.initialize().
        notificationsModule = NativeModuleRegistry.shared
            .module(named: "Notifications") as? NotificationsModule
        return true
    }

    // MARK: - Remote Notification Callbacks

    /// Called when APNs registration succeeds and provides the device token.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        notificationsModule?.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    /// Called when APNs registration fails.
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        notificationsModule?.didFailToRegisterForRemoteNotifications(error: error)
    }

    /// Called when a silent push or background notification arrives.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Forward to the bridge as a global event so JS can handle it
        NativeBridge.shared.dispatchGlobalEvent("push:received", payload: [
            "title": (userInfo["aps"] as? [String: Any])?["alert"] as? String ?? "",
            "body": "",
            "data": userInfo,
            "remote": true,
        ])
        completionHandler(.newData)
    }
}
```

::: tip
If you are using `VueNativeViewController` (the recommended approach), the bridge and module registry are already initialized in `viewDidLoad`. Make sure your AppDelegate grabs the `NotificationsModule` reference *after* the view controller has loaded.
:::

### 3. Info.plist (Optional)

For local notifications, iOS does not require an `NSUserNotificationsUsageDescription` key. The system permission dialog is triggered programmatically by `UNUserNotificationCenter.requestAuthorization()`.

However, if your app uses provisional or critical alerts, add this to your `Info.plist`:

```xml
<key>NSUserNotificationsUsageDescription</key>
<string>We send you reminders and updates about your tasks.</string>
```

### 4. Testing on iOS

**Simulator limitations:**
- The iOS Simulator does **not** support APNs. `registerForPush()` will call `didFailToRegisterForRemoteNotificationsWithError`.
- You can still test local notifications on the Simulator.
- To test push notifications, you must use a physical device.

**Testing with a real device:**
1. Build and run on a physical device with a valid provisioning profile that includes the Push Notification entitlement.
2. Call `registerForPush()` from your Vue component.
3. Check the Xcode console for the device token log: `[VueNative] push:token { token: "..." }`.
4. Use the token with your backend or a tool like [Knuff](https://github.com/KnuffApp/Knuff) to send a test push.

**Using an APNs sandbox `.p8` file:**
1. In the Apple Developer portal, go to **Keys** and create a new key with **Apple Push Notifications service (APNs)** enabled.
2. Download the `.p8` file and note the Key ID and Team ID.
3. Use these credentials with your push notification backend to send to the sandbox environment during development.

## Android Setup

### 1. Add Firebase Cloud Messaging Dependency

Add the Firebase Messaging dependency to your **app-level** `build.gradle`:

```groovy
// app/build.gradle
dependencies {
    // Vue Native core (already present)
    implementation project(':VueNativeCore')

    // Firebase Cloud Messaging
    implementation platform('com.google.firebase:firebase-bom:33.7.0')
    implementation 'com.google.firebase:firebase-messaging'
}

// Apply the Google services plugin (at the bottom of the file)
apply plugin: 'com.google.gms.google-services'
```

In your **project-level** `build.gradle`:

```groovy
// build.gradle (project level)
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.2'
    }
}
```

Download your `google-services.json` from the Firebase Console and place it in `app/`.

### 2. Create a FirebaseMessagingService Subclass

Create a service class that forwards FCM events to `NotificationsModule`:

```kotlin
package com.yourapp

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.vuenative.core.NotificationsModule

class MyFirebaseMessagingService : FirebaseMessagingService() {

    /**
     * Called when a new FCM token is generated or refreshed.
     * Forwards the token to NotificationsModule, which dispatches
     * a "push:token" global event to JavaScript.
     */
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        NotificationsModule.instance?.onNewToken(token)
    }

    /**
     * Called when a push message is received while the app is in the foreground,
     * or when a data-only message arrives (foreground or background).
     */
    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        val title = message.notification?.title ?: message.data["title"] ?: ""
        val body = message.notification?.body ?: message.data["body"] ?: ""
        val data = message.data

        NotificationsModule.instance?.onPushReceived(title, body, data)
    }
}
```

::: warning
`NotificationsModule.instance` is set during `NativeBridge.initialize()`. If a push arrives before the bridge is initialized (e.g., the app was killed and a push triggers a cold start), `instance` will be `null`. In that case, store the pending payload and forward it once the bridge is ready.
:::

### 3. AndroidManifest.xml

Register the service and declare the default notification channel in your `AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.yourapp">

    <!-- Required for Android 13+ (API 33) notification permission -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application ...>

        <!-- Your main activity (extends VueNativeActivity) -->
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <!-- Firebase Messaging Service -->
        <service
            android:name=".MyFirebaseMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>

        <!-- Default notification channel (matches NotificationsModule.CHANNEL_ID) -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="vue_native_default" />

    </application>
</manifest>
```

::: tip
The `vue_native_default` channel ID matches what `NotificationsModule` creates in `initialize()`. If you want a custom channel name or importance level, create it in your `MainActivity.onCreate()` before calling `super.onCreate()`.
:::

### 4. Android 13+ Runtime Permission

Starting with Android 13 (API 33), the `POST_NOTIFICATIONS` permission must be requested at runtime. Use the `usePermissions` composable alongside `useNotifications`:

```vue
<script setup>
import { useNotifications, usePermissions } from '@thelacanians/vue-native-runtime'

const { requestPermission: requestNotifPermission } = usePermissions()
const { registerForPush, onPushToken } = useNotifications()

async function setup() {
  // On Android 13+, request the runtime permission first
  const result = await requestNotifPermission('notifications')
  if (result === 'granted') {
    await registerForPush()
  }
}

setup()
</script>
```

## JavaScript Usage

Once the native wiring is in place, your Vue components interact with push notifications entirely through the `useNotifications()` composable.

### Requesting Permission and Registering

```vue
<script setup>
import { onMounted } from '@thelacanians/vue-native-runtime'
import { useNotifications } from '@thelacanians/vue-native-runtime'

const {
  isGranted,
  requestPermission,
  registerForPush,
  getToken,
  pushToken,
  onPushToken,
  onPushReceived,
} = useNotifications()

onMounted(async () => {
  // Step 1: Request notification permission
  const granted = await requestPermission()
  if (!granted) {
    console.warn('Notification permission denied')
    return
  }

  // Step 2: Register for remote push notifications
  // On iOS, this triggers APNs registration.
  // On Android, FCM auto-registers; this is a no-op.
  await registerForPush()

  // Step 3: Get the device token (may be null if not yet received)
  const token = await getToken()
  if (token) {
    console.log('Device token:', token)
    await sendTokenToBackend(token)
  }
})

// Step 4: Listen for token updates (fires on first registration and refreshes)
onPushToken(async (token) => {
  console.log('Push token received/refreshed:', token)
  await sendTokenToBackend(token)
})

// Step 5: Handle incoming push notifications
onPushReceived((notification) => {
  console.log('Push received:', notification.title, notification.body)
  console.log('Custom data:', notification.data)
  // Update your app state, show an in-app banner, navigate, etc.
})

async function sendTokenToBackend(token) {
  await fetch('https://api.yourapp.com/devices/register', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token, platform: 'ios' }), // or 'android'
  })
}
</script>
```

### Handling Foreground vs. Background Notifications

| Scenario | iOS Behavior | Android Behavior |
|---|---|---|
| App in **foreground** | `onPushReceived` fires immediately. Banner is shown (configurable via `UNNotificationPresentationOptions`). | `onPushReceived` fires for data messages. Notification messages are shown by the system. |
| App in **background** | System shows the notification. Tapping it opens the app and `onPushReceived` fires with an `action` field. | System shows the notification. `onMessageReceived` is called for data-only messages. |
| App **killed** | Tapping the notification cold-starts the app. The payload is delivered through `didReceiveRemoteNotification` in the AppDelegate. | Tapping the notification cold-starts the app. Data messages trigger `onMessageReceived`. |

### Global Events Reference

These are the bridge events that `useNotifications()` listens to internally:

| Event | Payload | When |
|---|---|---|
| `push:token` | `{ token: string }` | Device token received or refreshed |
| `push:received` | `{ title, body, data, remote: true }` | Remote push arrives (foreground) or is tapped (background) |
| `push:error` | `{ message: string }` | APNs registration failed (iOS only) |
| `notification:received` | `{ id, title, body, data, action? }` | Local notification received or tapped |

### Full Example: Push Notification Screen

```vue
<script setup>
import { ref, onMounted } from '@thelacanians/vue-native-runtime'
import { useNotifications } from '@thelacanians/vue-native-runtime'

const {
  isGranted,
  requestPermission,
  registerForPush,
  pushToken,
  onPushToken,
  onPushReceived,
} = useNotifications()

const lastPush = ref(null)
const error = ref('')

onMounted(async () => {
  const granted = await requestPermission()
  if (granted) {
    await registerForPush()
  } else {
    error.value = 'Permission denied'
  }
})

onPushToken(async (token) => {
  // Send to your backend
  try {
    await fetch('https://api.example.com/push/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token }),
    })
  } catch (e) {
    error.value = `Failed to register token: ${e.message}`
  }
})

onPushReceived((notification) => {
  lastPush.value = notification
})
</script>

<template>
  <VView :style="{ padding: 20, flex: 1 }">
    <VText :style="{ fontSize: 24, fontWeight: 'bold', marginBottom: 16 }">
      Push Notifications
    </VText>

    <VText>Permission: {{ isGranted ? 'Granted' : 'Not granted' }}</VText>
    <VText :style="{ marginTop: 8 }">
      Token: {{ pushToken || 'Waiting...' }}
    </VText>

    <VView v-if="lastPush" :style="{ marginTop: 20, padding: 16, backgroundColor: '#f0f0f0', borderRadius: 8 }">
      <VText :style="{ fontWeight: 'bold' }">Last Push Received:</VText>
      <VText>Title: {{ lastPush.title }}</VText>
      <VText>Body: {{ lastPush.body }}</VText>
      <VText>Data: {{ JSON.stringify(lastPush.data) }}</VText>
    </VView>

    <VText v-if="error" :style="{ color: 'red', marginTop: 16 }">
      {{ error }}
    </VText>
  </VView>
</template>
```

## Testing

### iOS Simulator

The iOS Simulator does **not** support APNs. You will see an error in `didFailToRegisterForRemoteNotificationsWithError`. To test push notifications:

- Use a **physical device** with a development provisioning profile.
- Use the Xcode **push notification simulator** (`.apns` file drag-and-drop onto Simulator, available in Xcode 11.4+) for basic testing of notification display, though `registerForPush()` will still fail.

### Real Device Testing (iOS)

1. Ensure your app has the Push Notifications capability and a valid provisioning profile.
2. Run the app, call `registerForPush()`, and capture the token from the `onPushToken` callback.
3. Send a test notification using the APNs HTTP/2 API or a tool:

```bash
# Using curl with a .p8 key (replace placeholders)
curl -v \
  --header "apns-topic: com.yourapp.bundleid" \
  --header "apns-push-type: alert" \
  --header "authorization: bearer $JWT_TOKEN" \
  --data '{"aps":{"alert":{"title":"Test","body":"Hello from APNs"}}}' \
  --http2 \
  https://api.sandbox.push.apple.com/3/device/$DEVICE_TOKEN
```

### Real Device Testing (Android)

1. Ensure `google-services.json` is in your `app/` directory.
2. Run the app and capture the FCM token from the `onPushToken` callback.
3. Send a test notification from the Firebase Console:
   - Go to **Firebase Console** > **Messaging** > **Compose notification**.
   - Enter a title and body.
   - Under **Target**, select **Single device** and paste the FCM token.
   - Click **Send test message**.

### Firebase Console (Both Platforms)

The Firebase Console can send to both iOS and Android if you have configured APNs credentials in the Firebase project:

1. Go to **Project Settings** > **Cloud Messaging**.
2. Under **Apple app configuration**, upload your APNs authentication key (`.p8` file) or certificate.
3. Once configured, sending from the Firebase Console will deliver to both platforms.

## Troubleshooting

| Problem | Cause | Solution |
|---|---|---|
| `push:token` never fires on iOS | APNs capability not added, or running on Simulator | Add Push Notifications capability in Xcode. Test on a real device. |
| `push:token` never fires on Android | `google-services.json` missing or service not registered | Verify the file is in `app/` and the service is in `AndroidManifest.xml`. |
| Token received but pushes don't arrive | Sending to wrong environment (sandbox vs. production) | Use `api.sandbox.push.apple.com` for debug builds, `api.push.apple.com` for release. |
| `onPushReceived` not called when app is in background | On Android, notification messages are handled by the system, not `onMessageReceived` | Use data-only messages (`data` field without `notification` field in the FCM payload) for guaranteed `onMessageReceived` delivery. |
| Android 13 notifications not showing | Missing `POST_NOTIFICATIONS` runtime permission | Request the permission using `usePermissions('notifications')` before scheduling or registering. |

## See Also

- [useNotifications composable](/composables/useNotifications.md) -- Full API reference for local and push notification methods.
- [iOS Setup](/ios/setup.md) -- General iOS project configuration.
- [Android Setup](/android/setup.md) -- General Android project configuration.
- [VueNativeViewController](/ios/VueNativeViewController.md) -- iOS base view controller.
- [VueNativeActivity](/android/VueNativeActivity.md) -- Android base activity.
