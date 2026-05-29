package com.vuenative.core

import android.app.Activity
import android.os.Handler
import android.os.Looper
import java.lang.ref.WeakReference

/**
 * Provides the default Android back behavior used when JS chooses not to
 * consume a hardware/gesture back event.
 */
class BackHandlerModule : NativeModule {
    override val moduleName = "BackHandler"

    companion object {
        private var activityRef: WeakReference<Activity>? = null
        private val mainHandler = Handler(Looper.getMainLooper())

        fun setActivity(activity: Activity?) {
            activityRef = activity?.let { WeakReference(it) }
        }
    }

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit
    ) {
        when (method) {
            "exitApp" -> mainHandler.post {
                val activity = activityRef?.get()
                if (activity == null || activity.isFinishing) {
                    callback(false, "No active Activity")
                } else {
                    activity.finish()
                    callback(true, null)
                }
            }
            else -> callback(null, "Unknown method: $method")
        }
    }
}
