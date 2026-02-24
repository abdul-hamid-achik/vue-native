# useBackgroundTask

Schedule and manage background tasks that run even when your app is not in the foreground. Uses `BGTaskScheduler` on iOS and `WorkManager` on Android.

## Usage

```vue
<script setup>
import { useBackgroundTask } from '@thelacanians/vue-native-runtime'

const {
  scheduleTask, cancelTask, cancelAllTasks,
  completeTask, registerTask, onTaskExecute,
} = useBackgroundTask()

// Handle background task execution
onTaskExecute((taskId) => {
  console.log('Background task executing:', taskId)
  // Do your work, then signal completion
  syncData().then(() => completeTask(taskId))
})

// Schedule a background refresh
async function scheduleSync() {
  await scheduleTask('com.myapp.sync', {
    type: 'refresh',
    requiresNetworkConnectivity: true,
    earliestBeginDate: Date.now() + 15 * 60 * 1000, // 15 min from now
  })
}
</script>
```

## Setup

### iOS

Register your task identifiers in `Info.plist`:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
  <string>com.myapp.sync</string>
  <string>com.myapp.cleanup</string>
</array>
```

Enable the "Background processing" and/or "Background fetch" capabilities in Xcode.

### Android

Add WorkManager to your `build.gradle` dependencies (already included in VueNativeCore):

```gradle
implementation "androidx.work:work-runtime-ktx:2.9.0"
```

No additional manifest entries are required; WorkManager handles them automatically.

## API

```ts
useBackgroundTask(): {
  registerTask: (taskId: string) => Promise<void>
  scheduleTask: (taskId: string, options?: BackgroundTaskOptions) => Promise<void>
  cancelTask: (taskId: string) => Promise<void>
  cancelAllTasks: () => Promise<void>
  completeTask: (taskId: string, success?: boolean) => Promise<void>
  onTaskExecute: (handler: (taskId: string) => void, taskId?: string) => () => void
}
```

### Methods

#### `registerTask(taskId)`

Register a task identifier with the OS. On iOS, this sets up the `BGTaskScheduler` handler. On Android, this is a no-op (registration happens automatically at schedule time).

| Parameter | Type | Description |
|-----------|------|-------------|
| `taskId` | `string` | The task identifier (e.g., `'com.myapp.sync'`). Must match `Info.plist` on iOS. |

#### `scheduleTask(taskId, options?)`

Schedule a background task for future execution.

| Parameter | Type | Description |
|-----------|------|-------------|
| `taskId` | `string` | The task identifier. |
| `options` | `BackgroundTaskOptions?` | Scheduling options. |

**BackgroundTaskOptions:**

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `type` | `'refresh' \| 'processing'` | `'refresh'` | Task type. `'refresh'` for short tasks (~30s), `'processing'` for long-running tasks. |
| `earliestBeginDate` | `number?` | - | Earliest time the task can begin (Unix timestamp in ms). |
| `requiresNetworkConnectivity` | `boolean?` | `false` | Whether the task needs network access. |
| `requiresExternalPower` | `boolean?` | `false` | Whether the device must be charging. |
| `interval` | `number?` | `15` | Interval in minutes for periodic tasks (Android only, requires `type: 'processing'`). |

#### `cancelTask(taskId)`

Cancel a scheduled task.

| Parameter | Type | Description |
|-----------|------|-------------|
| `taskId` | `string` | The task identifier to cancel. |

#### `cancelAllTasks()`

Cancel all scheduled background tasks.

#### `completeTask(taskId, success?)`

Signal that a background task has finished. **Must be called** on iOS when `onTaskExecute` fires, or the system will throttle future tasks.

| Parameter | Type | Default | Description |
|----------|------|---------|-------------|
| `taskId` | `string` | - | The task identifier. |
| `success` | `boolean?` | `true` | Whether the task completed successfully. |

#### `onTaskExecute(handler, taskId?)`

Register a callback for when a background task executes. Returns an unsubscribe function.

| Parameter | Type | Description |
|-----------|------|-------------|
| `handler` | `(taskId: string) => void` | Called when a task fires. |
| `taskId` | `string?` | If provided, only fires for this specific task. Otherwise acts as a catch-all. |

## Platform Differences

| Feature | iOS | Android |
|---------|-----|---------|
| Short refresh tasks | `BGAppRefreshTaskRequest` (~30s) | `OneTimeWorkRequest` |
| Long processing tasks | `BGProcessingTaskRequest` (minutes) | `PeriodicWorkRequest` |
| Registration | Must list in `Info.plist` | Automatic |
| `completeTask()` | Required (system enforced) | No-op (Worker handles completion) |
| Periodic tasks | Not supported (reschedule manually) | Built-in via `interval` option |
| Minimum interval | System-determined | 15 minutes (WorkManager minimum) |

## Example

```vue
<script setup>
import { onMounted } from '@thelacanians/vue-native-runtime'
import { useBackgroundTask } from '@thelacanians/vue-native-runtime'

const { scheduleTask, cancelTask, completeTask, onTaskExecute } = useBackgroundTask()

onTaskExecute(async (taskId) => {
  try {
    // Perform sync work
    const response = await fetch('https://api.myapp.com/sync')
    const data = await response.json()
    await saveData(data)
    await completeTask(taskId, true)
  } catch (error) {
    await completeTask(taskId, false)
  }
}, 'com.myapp.datasync')

onMounted(async () => {
  await scheduleTask('com.myapp.datasync', {
    type: 'refresh',
    requiresNetworkConnectivity: true,
    earliestBeginDate: Date.now() + 60 * 60 * 1000, // 1 hour from now
  })
})
</script>

<template>
  <VView :style="{ flex: 1, justifyContent: 'center', alignItems: 'center' }">
    <VText>Background sync is scheduled</VText>
    <VButton :onPress="() => cancelTask('com.myapp.datasync')">
      <VText>Cancel Sync</VText>
    </VButton>
  </VView>
</template>
```

## Notes

- Background task execution is controlled by the OS and may not run exactly at the scheduled time.
- iOS aggressively throttles background tasks for apps with low usage. Tasks may be delayed significantly.
- Always call `completeTask()` on iOS when your handler finishes. Failing to do so causes the system to terminate your task and reduces future scheduling priority.
- On Android, the minimum interval for periodic tasks is 15 minutes (WorkManager limitation).
- Background tasks should be designed to be idempotent — they may run more than once or not at all.
