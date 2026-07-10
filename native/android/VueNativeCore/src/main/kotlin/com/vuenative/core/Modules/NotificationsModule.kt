package com.vuenative.core

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.util.UUID

/**
 * Native module for local and remote (push) notifications.
 *
 * For push notifications, the host app must:
 * 1. Add Firebase Messaging dependency to their app-level build.gradle
 * 2. Create a FirebaseMessagingService subclass that calls
 *    NotificationsModule.onNewToken() and onPushReceived()
 *
 * Methods:
 *   - requestPermission() -> Boolean
 *   - getPermissionStatus() -> "granted"|"denied"|"notDetermined"
 *   - scheduleLocal(opts) -> notificationId: String
 *   - cancel(id)
 *   - cancelAll()
 *   - registerForPush() -> true (no-op on Android; FCM auto-registers)
 *   - getToken() -> String? (returns cached FCM token)
 *
 * Host-forwarded global events:
 *   "notification:received" -- local notification tapped (host integration required)
 *   "push:token"     { token }
 *   "push:received"  { title, body, data, remote: true }
 */
class NotificationsModule : NativeModule {
    override val moduleName = "Notifications"

    private var context: Context? = null
    private var bridge: NativeBridge? = null
    private var permissionsModule: PermissionsModule? = null
    private val handler = Handler(Looper.getMainLooper())
    private val pendingNotifications = mutableMapOf<String, Runnable>()

    companion object {
        private const val CHANNEL_ID = "vue_native_default"
        private const val LOCAL_NOTIFICATION_ID = 1

        /** Singleton reference so FirebaseMessagingService can call into this module. */
        @Volatile
        var instance: NotificationsModule? = null
            private set
    }

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context.applicationContext
        this.bridge = bridge
        this.permissionsModule = NativeModuleRegistry.getInstance(context)
            .getModule("Permissions") as? PermissionsModule
        instance = this
        createDefaultChannel(context.applicationContext)
    }

    private fun createDefaultChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Notifications",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Vue Native app notifications"
            }
            ctx.getSystemService(NotificationManager::class.java)
                ?.createNotificationChannel(channel)
        }
    }

    // -------------------------------------------------------------------------
    // Push token handling (called from FirebaseMessagingService in host app)
    // -------------------------------------------------------------------------

    /** Cached FCM token. Volatile because onNewToken() is called from FCM background thread
     *  while getToken() may be called from the module invocation thread. */
    @Volatile
    private var fcmToken: String? = null

    /**
     * Called by the host app's FirebaseMessagingService.onNewToken().
     */
    fun onNewToken(token: String) {
        fcmToken = token
        bridge?.dispatchGlobalEvent("push:token", mapOf("token" to token))
    }

    /**
     * Called by the host app's FirebaseMessagingService.onMessageReceived().
     */
    fun onPushReceived(title: String, body: String, data: Map<String, String>) {
        bridge?.dispatchGlobalEvent("push:received", mapOf(
            "title" to title,
            "body" to body,
            "data" to data,
            "remote" to true
        ))
    }

    // -------------------------------------------------------------------------
    // Module invocation
    // -------------------------------------------------------------------------

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit
    ) {
        when (method) {
            "requestPermission" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                    callback(true, null)
                    return
                }

                val permissions = resolvePermissionsModule() ?: run {
                    callback(null, "NotificationsModule: Permissions module is unavailable")
                    return
                }
                permissions.requestNamedPermission("notifications", this) { status, error ->
                    if (error != null) {
                        callback(null, error)
                    } else {
                        callback(status == "granted", null)
                    }
                }
            }
            "getPermissionStatus" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                    callback("granted", null)
                    return
                }

                val permissions = resolvePermissionsModule() ?: run {
                    callback(null, "NotificationsModule: Permissions module is unavailable")
                    return
                }
                permissions.checkNamedPermission("notifications", callback)
            }
            "scheduleLocal" -> {
                val ctx = context ?: run {
                    callback(null, "Not initialized")
                    return
                }
                val opts = args.getOrNull(0) as? Map<*, *>
                    ?: run {
                        callback(null, "Invalid args — expected options object")
                        return
                    }

                val title = opts["title"]?.toString() ?: ""
                val body = opts["body"]?.toString() ?: ""
                val delaySeconds = (opts["delay"] as? Number)?.toDouble() ?: 0.0
                val delayMillis = (delaySeconds.coerceAtLeast(0.0) * 1000.0)
                    .coerceAtMost(Long.MAX_VALUE.toDouble())
                    .toLong()
                val notificationId = (opts["id"] as? String)
                    ?.takeIf(String::isNotBlank)
                    ?: UUID.randomUUID().toString()

                val show = Runnable {
                    pendingNotifications.remove(notificationId)
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                        ActivityCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS)
                        == PackageManager.PERMISSION_GRANTED
                    ) {
                        val builder = NotificationCompat.Builder(ctx, CHANNEL_ID)
                            .setSmallIcon(android.R.drawable.ic_dialog_info)
                            .setContentTitle(title)
                            .setContentText(body)
                            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                            .setAutoCancel(true)

                        if (opts["sound"] == "default") {
                            builder.setDefaults(Notification.DEFAULT_SOUND)
                        }
                        (opts["badge"] as? Number)?.toInt()?.let { badge ->
                            builder.setNumber(badge.coerceAtLeast(0))
                        }

                        NotificationManagerCompat.from(ctx).notify(
                            notificationId,
                            LOCAL_NOTIFICATION_ID,
                            builder.build(),
                        )
                    }
                }

                pendingNotifications.remove(notificationId)?.let(handler::removeCallbacks)
                if (delayMillis > 0) {
                    pendingNotifications[notificationId] = show
                    handler.postDelayed(show, delayMillis)
                } else {
                    show.run()
                }
                callback(notificationId, null)
            }
            "cancel" -> {
                val ctx = context ?: run {
                    callback(null, "Not initialized")
                    return
                }
                val id = (args.getOrNull(0) as? String)?.takeIf(String::isNotBlank)
                    ?: run {
                        callback(null, "Invalid args — expected notification id")
                        return
                    }
                pendingNotifications.remove(id)?.let(handler::removeCallbacks)
                NotificationManagerCompat.from(ctx).cancel(id, LOCAL_NOTIFICATION_ID)
                callback(null, null)
            }
            "cancelAll" -> {
                val ctx = context ?: run {
                    callback(null, "Not initialized")
                    return
                }
                pendingNotifications.values.forEach(handler::removeCallbacks)
                pendingNotifications.clear()
                NotificationManagerCompat.from(ctx).cancelAll()
                callback(null, null)
            }
            "registerForPush" -> {
                // On Android, FCM auto-registers. This is a no-op for API parity with iOS.
                callback(true, null)
            }
            "getToken" -> {
                callback(fcmToken, null)
            }
            else -> callback(null, "Unknown method: $method")
        }
    }

    private fun resolvePermissionsModule(): PermissionsModule? {
        permissionsModule?.let { return it }
        val ctx = context ?: return null
        return (NativeModuleRegistry.getInstance(ctx).getModule("Permissions") as? PermissionsModule)
            ?.also { permissionsModule = it }
    }

    override fun destroy() {
        handler.removeCallbacksAndMessages(null)
        pendingNotifications.clear()
        permissionsModule?.cancelPendingRequests(
            this,
            "Notification permission request cancelled because the native host was destroyed",
        )
        if (instance === this) instance = null
        context = null
        bridge = null
        permissionsModule = null
        fcmToken = null
    }
}
