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

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses `UNUserNotificationCenter` for scheduling and permissions. Foreground notifications display as banners. |
| Android | Uses `NotificationManager` for scheduling. Permission required on API 33+ (Android 13). |

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
    <VButton title="Request Permission" :onPress="requestPermission" />

    <VButton
      title="Schedule in 5s"
      :onPress="scheduleReminder"
      :style="{ marginTop: 16 }"
    />
    <VButton title="Cancel Scheduled" :onPress="cancelReminder" />
    <VButton title="Cancel All" :onPress="cancelAll" />

    <VText :style="{ marginTop: 16 }">
      Last received: {{ lastNotification || 'None' }}
    </VText>
  </VView>
</template>
```

## Notes

- The `onNotification` handler fires both when a notification arrives while the app is in the foreground and when the user taps a notification to open the app.
- The handler is automatically unsubscribed when the component is unmounted via `onUnmounted`. You can also call the returned unsubscribe function manually.
- The `delay` has a minimum value of 0.1 seconds on iOS (enforced by `UNTimeIntervalNotificationTrigger`). If you pass `0` or omit it, `0.1` is used.
- The `isGranted` ref is only updated when you call `requestPermission()`. It is not automatically synced with the system permission state.
- Notification scheduling is local only. For remote push notifications, you need to configure APNs (iOS) or FCM (Android) separately.
