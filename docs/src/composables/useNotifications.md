# useNotifications

Schedule and manage local notifications, request notification permissions, and listen for notification events when the app is in the foreground.

## Usage

```vue
<script setup>
import { useNotifications } from '@thelacanians/vue-native-runtime'

const { requestPermission, scheduleLocal, onNotification } = useNotifications()

async function setup() {
  const granted = await requestPermission()
  if (granted) {
    await scheduleLocal({
      title: 'Reminder',
      body: 'Time to take a break!',
      delay: 10,
    })
  }
}

onNotification((payload) => {
  console.log('Notification received:', payload.title)
})
</script>
```

## API

```ts
useNotifications(): {
  isGranted: Ref<boolean>
  requestPermission: () => Promise<boolean>
  getPermissionStatus: () => Promise<string>
  scheduleLocal: (notification: LocalNotification) => Promise<string>
  cancel: (id: string) => Promise<void>
  cancelAll: () => Promise<void>
  onNotification: (handler: (payload: NotificationPayload) => void) => () => void
  pushToken: Ref<string | null>
  registerForPush: () => Promise<void>
  getToken: () => Promise<string | null>
  onPushToken: (handler: (token: string) => void) => () => void
  onPushReceived: (handler: (payload: PushNotificationPayload) => void) => () => void
  onPushError: (handler: (error: { message: string }) => void) => () => void
}
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `isGranted` | `Ref<boolean>` | Whether notification permission has been granted. Updated after calling `requestPermission()`. |
| `requestPermission` | `() => Promise<boolean>` | Request notification permission from the user. Returns `true` if granted. Also updates `isGranted`. |
| `getPermissionStatus` | `() => Promise<string>` | Get the current permission status without prompting. Returns `'granted'`, `'denied'`, or `'notDetermined'`. |
| `scheduleLocal` | `(notification: LocalNotification) => Promise<string>` | Schedule a local notification. Returns the notification ID. |
| `cancel` | `(id: string) => Promise<void>` | Cancel a pending notification by ID. |
| `cancelAll` | `() => Promise<void>` | Cancel all pending notifications. |
| `onNotification` | `(handler) => () => void` | Register a handler for received notifications. Returns an unsubscribe function. Automatically cleaned up on component unmount. |
| `pushToken` | `Ref<string \| null>` | Latest token delivered through `onPushToken`; initially `null`. |
| `registerForPush` | `() => Promise<void>` | Start APNs registration on iOS. This is an API-parity no-op on Android because FCM registers independently. Not available on macOS. |
| `getToken` | `() => Promise<string \| null>` | Return the token cached by the native module, or `null` before one is available. Not available on macOS. |
| `onPushToken` | `(handler: (token: string) => void) => () => void` | Listen for initial and refreshed push tokens. Also updates `pushToken`. |
| `onPushReceived` | `(handler: (payload: PushNotificationPayload) => void) => () => void` | Listen for remote push payloads forwarded by the native host. |
| `onPushError` | `(handler: (error: { message: string }) => void) => () => void` | Listen for push-registration failures forwarded by the native host. |

### LocalNotification

| Property | Type | Description |
|----------|------|-------------|
| `id` | `string?` | Optional notification ID. A UUID is generated if not provided. |
| `title` | `string` | Notification title. |
| `body` | `string` | Notification body text. |
| `delay` | `number?` | Delay in seconds before showing the notification. Minimum is 0.1 seconds. |
| `sound` | `'default' \| null?` | Play the default notification sound, or `null` for silent. |
| `badge` | `number?` | App badge number to set. |
| `data` | `Record<string, any>?` | Custom data payload attached to the notification. |

### NotificationPayload

Received by the `onNotification` handler:

| Property | Type | Description |
|----------|------|-------------|
| `id` | `string` | The notification identifier. |
| `title` | `string` | Notification title. |
| `body` | `string` | Notification body text. |
| `data` | `Record<string, any>` | Custom data attached to the notification. |
| `action` | `string?` | The action identifier if the user tapped a notification action button (iOS). |

### PushNotificationPayload

Received by the `onPushReceived` handler:

| Property | Type | Description |
|----------|------|-------------|
| `id` | `string?` | Native notification identifier when available. |
| `title` | `string` | Remote notification title. |
| `body` | `string` | Remote notification body. |
| `data` | `Record<string, unknown>` | Custom payload forwarded by the native host. |
| `remote` | `true` | Distinguishes remote notifications from local notification events. |
| `action` | `string?` | Action identifier when the user taps an action. |

## Push Notifications

```ts
const {
  pushToken,
  registerForPush,
  getToken,
  onPushToken,
  onPushReceived,
  onPushError,
} = useNotifications()

onPushToken((token) => {
  console.log('Register token with your backend:', token)
})

onPushReceived((notification) => {
  console.log('Remote notification:', notification.title)
})

onPushError((error) => {
  console.error('Push registration failed:', error.message)
})

await registerForPush()
console.log('Cached token:', await getToken(), pushToken.value)
```

APNs and FCM still require native host configuration. See the [push notification setup guide](/guide/push-notifications.md) for the platform wiring.

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses `UNUserNotificationCenter` for scheduling and permissions. APNs tokens and background callbacks use the public bridge facade described in the [push notifications guide](/guide/push-notifications.md). |
| Android | Uses `NotificationManager` for scheduling. Permission required on API 33+ (Android 13). FCM callbacks must be forwarded from a `FirebaseMessagingService`. |
| macOS | Uses `UNUserNotificationCenter` for local scheduling and permission status. `registerForPush()` rejects and `getToken()` returns `null`; push event hooks remain idle unless a host forwards those events. |

## Example

```vue
<script setup>
import { ref, onMounted } from '@thelacanians/vue-native-runtime'
import { useNotifications } from '@thelacanians/vue-native-runtime'

const { isGranted, requestPermission, getPermissionStatus, scheduleLocal, cancel, cancelAll, onNotification } = useNotifications()
const lastNotification = ref('')
const scheduledId = ref('')

onMounted(async () => {
  const status = await getPermissionStatus()
  if (status === 'notDetermined') {
    await requestPermission()
  }
})

onNotification((payload) => {
  lastNotification.value = `${payload.title}: ${payload.body}`
})

async function scheduleReminder() {
  scheduledId.value = await scheduleLocal({
    title: 'Hello',
    body: 'This notification was scheduled 5 seconds ago',
    delay: 5,
    sound: 'default',
    data: { screen: 'home' },
  })
}

async function cancelReminder() {
  if (scheduledId.value) {
    await cancel(scheduledId.value)
    scheduledId.value = ''
  }
}
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VText>Permission granted: {{ isGranted }}</VText>
    <VButton :onPress="requestPermission"><VText>Request Permission</VText></VButton>

    <VButton
      :onPress="scheduleReminder"
      :style="{ marginTop: 16 }"
    >
      <VText>Schedule in 5s</VText>
    </VButton>
    <VButton :onPress="cancelReminder"><VText>Cancel Scheduled</VText></VButton>
    <VButton :onPress="cancelAll"><VText>Cancel All</VText></VButton>

    <VText :style="{ marginTop: 16 }">
      Last received: {{ lastNotification || 'None' }}
    </VText>
  </VView>
</template>
```

## Notes

- On iOS, `onNotification` fires for foreground delivery and notification taps. Android hosts must forward their notification tap/foreground payloads to the Vue Native bridge; the base local scheduler does not synthesize those events.
- The handler is automatically unsubscribed when the component is unmounted via `onUnmounted`. You can also call the returned unsubscribe function manually.
- The `delay` has a minimum value of 0.1 seconds on iOS (enforced by `UNTimeIntervalNotificationTrigger`). If you pass `0` or omit it, `0.1` is used.
- The `isGranted` ref is only updated when you call `requestPermission()`. It is not automatically synced with the system permission state.
- Notification scheduling is local only. For remote push notifications, you need to configure APNs (iOS) or FCM (Android) separately.
- The public iOS AppDelegate facade and Android's `NotificationsModule.instance.onNewToken()` both update the native token cache before emitting `push:token`, so `getToken()` can recover a token that arrived before a JavaScript listener was registered.
- Android delayed local notifications use an in-process timer. For reminders that must survive process death or device restart, integrate WorkManager/AlarmManager or send an FCM notification from your backend.
