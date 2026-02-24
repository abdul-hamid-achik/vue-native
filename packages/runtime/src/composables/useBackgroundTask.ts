import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

export type BackgroundTaskType = 'refresh' | 'processing'

export interface BackgroundTaskOptions {
  /** Task type: 'refresh' for short tasks, 'processing' for long-running tasks. */
  type?: BackgroundTaskType
  /** Earliest time the task can begin (Unix timestamp in ms). */
  earliestBeginDate?: number
  /** Whether the task requires network connectivity. */
  requiresNetworkConnectivity?: boolean
  /** Whether the task requires the device to be charging. */
  requiresExternalPower?: boolean
  /** Interval in minutes for periodic tasks (Android only, type must be 'processing'). */
  interval?: number
}

/**
 * Composable for scheduling and managing background tasks.
 *
 * Uses BGTaskScheduler on iOS and WorkManager on Android.
 *
 * @example
 * ```ts
 * const { scheduleTask, cancelTask, onTaskExecute } = useBackgroundTask()
 *
 * onTaskExecute((taskId) => {
 *   // Perform work, then signal completion
 *   doWork().then(() => completeTask(taskId))
 * })
 *
 * await scheduleTask('com.myapp.sync', {
 *   type: 'refresh',
 *   requiresNetworkConnectivity: true,
 * })
 * ```
 */
export function useBackgroundTask() {
  const taskHandlers = new Map<string, (taskId: string) => void>()
  const defaultHandler = ref<((taskId: string) => void) | null>(null)

  const unsubscribe = NativeBridge.onGlobalEvent('background:taskExecute', (payload: { taskId: string }) => {
    const handler = taskHandlers.get(payload.taskId) || defaultHandler.value
    if (handler) {
      handler(payload.taskId)
    }
  })

  onUnmounted(unsubscribe)

  function registerTask(taskId: string): Promise<void> {
    return NativeBridge.invokeNativeModule('BackgroundTask', 'registerTask', [taskId]).then(() => undefined)
  }

  function scheduleTask(taskId: string, options: BackgroundTaskOptions = {}): Promise<void> {
    const type = options.type ?? 'refresh'
    return NativeBridge.invokeNativeModule('BackgroundTask', 'scheduleTask', [taskId, type, {
      earliestBeginDate: options.earliestBeginDate,
      requiresNetworkConnectivity: options.requiresNetworkConnectivity,
      requiresExternalPower: options.requiresExternalPower,
      interval: options.interval,
    }]).then(() => undefined)
  }

  function cancelTask(taskId: string): Promise<void> {
    return NativeBridge.invokeNativeModule('BackgroundTask', 'cancelTask', [taskId]).then(() => undefined)
  }

  function cancelAllTasks(): Promise<void> {
    return NativeBridge.invokeNativeModule('BackgroundTask', 'cancelAllTasks', []).then(() => undefined)
  }

  function completeTask(taskId: string, success = true): Promise<void> {
    return NativeBridge.invokeNativeModule('BackgroundTask', 'completeTask', [taskId, success]).then(() => undefined)
  }

  /**
   * Register a handler for when a background task executes.
   * If taskId is provided, the handler is called only for that task.
   * If no taskId, the handler is used as a catch-all.
   */
  function onTaskExecute(handler: (taskId: string) => void, taskId?: string): () => void {
    if (taskId) {
      taskHandlers.set(taskId, handler)
      return () => {
        taskHandlers.delete(taskId)
      }
    } else {
      defaultHandler.value = handler
      return () => {
        defaultHandler.value = null
      }
    }
  }

  return { registerTask, scheduleTask, cancelTask, cancelAllTasks, completeTask, onTaskExecute }
}
