package com.vuenative.core

import android.content.Context
import android.util.Log
import androidx.work.*
import java.util.concurrent.TimeUnit

/**
 * Native module for scheduling background tasks using WorkManager.
 *
 * Methods:
 *   - scheduleTask(taskId, type, options) — schedule a one-time or periodic task
 *   - cancelTask(taskId) — cancel a specific task
 *   - cancelAllTasks() — cancel all scheduled tasks
 *   - completeTask(taskId) — no-op on Android (Worker handles completion)
 *   - registerTask(taskId) — no-op on Android (registration is automatic)
 *
 * Events:
 *   - background:taskExecute — fired when a background task runs, payload: { taskId }
 */
class BackgroundTaskModule : NativeModule {
    override val moduleName = "BackgroundTask"
    private var appContext: Context? = null
    private var bridgeRef: NativeBridge? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        appContext = context.applicationContext
        bridgeRef = bridge
        // Store bridge reference for the worker
        VueNativeWorker.bridgeRef = bridge
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val ctx = appContext ?: run {
            callback(null, "BackgroundTask not initialized")
            return
        }

        when (method) {
            "scheduleTask" -> {
                val taskId = args.getOrNull(0)?.toString()
                    ?: run {
                        callback(null, "scheduleTask: missing taskId")
                        return
                    }
                val type = args.getOrNull(1)?.toString() ?: "refresh"
                val options = args.getOrNull(2) as? Map<*, *> ?: emptyMap<String, Any>()
                scheduleTask(ctx, taskId, type, options, callback)
            }
            "cancelTask" -> {
                val taskId = args.getOrNull(0)?.toString()
                    ?: run {
                        callback(null, "cancelTask: missing taskId")
                        return
                    }
                WorkManager.getInstance(ctx).cancelUniqueWork(taskId)
                callback(null, null)
            }
            "cancelAllTasks" -> {
                WorkManager.getInstance(ctx).cancelAllWork()
                callback(null, null)
            }
            "completeTask" -> {
                // On Android, WorkManager Workers handle their own completion
                callback(null, null)
            }
            "registerTask" -> {
                // No-op on Android — registration happens at schedule time
                callback(null, null)
            }
            else -> callback(null, "BackgroundTaskModule: Unknown method '$method'")
        }
    }

    private fun scheduleTask(
        ctx: Context,
        taskId: String,
        type: String,
        options: Map<*, *>,
        callback: (Any?, String?) -> Unit
    ) {
        try {
            val constraintsBuilder = Constraints.Builder()

            val requiresNetwork = options["requiresNetworkConnectivity"] as? Boolean ?: false
            if (requiresNetwork) {
                constraintsBuilder.setRequiredNetworkType(NetworkType.CONNECTED)
            }

            val requiresCharging = options["requiresExternalPower"] as? Boolean ?: false
            if (requiresCharging) {
                constraintsBuilder.setRequiresCharging(true)
            }

            val constraints = constraintsBuilder.build()

            val inputData = Data.Builder()
                .putString("taskId", taskId)
                .build()

            if (type == "processing") {
                // Periodic work for long-running/processing tasks
                val intervalMinutes = (options["interval"] as? Number)?.toLong() ?: 15L
                val request = PeriodicWorkRequestBuilder<VueNativeWorker>(
                    intervalMinutes, TimeUnit.MINUTES
                )
                    .setConstraints(constraints)
                    .setInputData(inputData)
                    .addTag("vue-native-bg-$taskId")
                    .build()

                WorkManager.getInstance(ctx).enqueueUniquePeriodicWork(
                    taskId,
                    ExistingPeriodicWorkPolicy.REPLACE,
                    request
                )
            } else {
                // One-time work for refresh tasks
                val requestBuilder = OneTimeWorkRequestBuilder<VueNativeWorker>()
                    .setConstraints(constraints)
                    .setInputData(inputData)
                    .addTag("vue-native-bg-$taskId")

                val delayMs = (options["earliestBeginDate"] as? Number)?.toLong()
                if (delayMs != null) {
                    val now = System.currentTimeMillis()
                    val delay = delayMs - now
                    if (delay > 0) {
                        requestBuilder.setInitialDelay(delay, TimeUnit.MILLISECONDS)
                    }
                }

                WorkManager.getInstance(ctx).enqueueUniqueWork(
                    taskId,
                    ExistingWorkPolicy.REPLACE,
                    requestBuilder.build()
                )
            }

            callback(null, null)
        } catch (e: Exception) {
            callback(null, "Failed to schedule task: ${e.message}")
        }
    }

    override fun destroy() {
        VueNativeWorker.bridgeRef = null
    }
}

/**
 * Worker that fires background:taskExecute events back to the JS bridge.
 */
class VueNativeWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    companion object {
        @Volatile
        var bridgeRef: NativeBridge? = null
    }

    override fun doWork(): Result {
        val taskId = inputData.getString("taskId") ?: return Result.failure()

        try {
            bridgeRef?.dispatchGlobalEvent(
                "background:taskExecute",
                mapOf("taskId" to taskId)
            )
        } catch (e: Exception) {
            Log.e("VueNative", "BackgroundTask execution failed", e)
            return Result.failure()
        }

        return Result.success()
    }
}
