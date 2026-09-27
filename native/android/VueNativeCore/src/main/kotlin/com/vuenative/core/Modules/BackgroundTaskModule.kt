package com.vuenative.core

import android.content.Context
import android.util.Log
import androidx.work.*
import java.lang.ref.WeakReference
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

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
        // Only clear the process-wide Worker slot if this module still owns it —
        // a replacement host may have already installed its own bridge.
        bridgeRef?.let { VueNativeWorker.clearBridge(it) }
        bridgeRef = null
        appContext = null
    }
}

/**
 * Worker that fires background:taskExecute events back to the JS bridge.
 */
class VueNativeWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    companion object {
        private val bridgeSlot = AtomicReference<WeakReference<NativeBridge>?>(null)

        /**
         * The bridge a running Worker dispatches `background:taskExecute` to.
         *
         * Held **weakly** on purpose: [NativeBridge] retains its host Activity,
         * this slot is a process-wide static, and WorkManager can run a Worker
         * long after that Activity was destroyed. A strong reference here leaks
         * the whole Activity (and its view tree) for the life of the process.
         * Readers must tolerate `null` — that just means "no live host".
         */
        var bridgeRef: NativeBridge?
            get() = bridgeSlot.get()?.get()
            set(value) {
                bridgeSlot.set(value?.let { WeakReference(it) })
            }

        /**
         * Clear the slot only when it still points at [bridge]. A retiring host
         * must not wipe the reference a replacement host already installed.
         *
         * Written as an explicit CAS loop rather than
         * `AtomicReference.updateAndGet`, which is a `java.util.concurrent`
         * default method and only exists on API 24+ (minSdk here is 21).
         */
        fun clearBridge(bridge: NativeBridge) {
            while (true) {
                val current = bridgeSlot.get() ?: return
                if (current.get() !== bridge) return
                if (bridgeSlot.compareAndSet(current, null)) return
            }
        }
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
