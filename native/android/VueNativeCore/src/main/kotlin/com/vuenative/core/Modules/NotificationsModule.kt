package com.vuenative.core

import android.Manifest
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

class NotificationsModule : NativeModule {
    override val moduleName = "Notifications"

    private var context: Context? = null
    private val handler = Handler(Looper.getMainLooper())
    private var notifIdCounter = 1

    companion object {
        private const val CHANNEL_ID = "vue_native_default"
    }

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context
        createDefaultChannel(context)
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

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit
    ) {
        when (method) {
            "requestPermission" -> {
                // Android <13: no runtime permission needed for notifications
                // Android 13+: POST_NOTIFICATIONS must be granted via PermissionsModule
                val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    val ctx = context ?: run { callback(null, "Not initialized"); return }
                    ActivityCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) ==
                            PackageManager.PERMISSION_GRANTED
                } else {
                    true
                }
                callback(mapOf("status" to if (granted) "granted" else "denied"), null)
            }
            "scheduleLocal" -> {
                val ctx = context ?: run { callback(null, "Not initialized"); return }
                val opts = args.getOrNull(0) as? Map<*, *>
                    ?: run { callback(null, "Invalid args — expected options object"); return }

                val title = opts["title"]?.toString() ?: ""
                val body = opts["body"]?.toString() ?: ""
                val delaySeconds = (opts["delay"] as? Number)?.toLong() ?: 0L
                val notifId = notifIdCounter++

                val show = Runnable {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                        ActivityCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS)
                        == PackageManager.PERMISSION_GRANTED
                    ) {
                        val notification = NotificationCompat.Builder(ctx, CHANNEL_ID)
                            .setSmallIcon(android.R.drawable.ic_dialog_info)
                            .setContentTitle(title)
                            .setContentText(body)
                            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                            .setAutoCancel(true)
                            .build()
                        NotificationManagerCompat.from(ctx).notify(notifId, notification)
                    }
                }

                if (delaySeconds > 0) {
                    handler.postDelayed(show, delaySeconds * 1000L)
                } else {
                    show.run()
                }
                callback(mapOf("id" to notifId), null)
            }
            "cancel" -> {
                val ctx = context ?: run { callback(null, "Not initialized"); return }
                val id = (args.getOrNull(0) as? Number)?.toInt()
                    ?: run { callback(null, "Invalid args — expected notification id"); return }
                NotificationManagerCompat.from(ctx).cancel(id)
                callback(null, null)
            }
            "cancelAll" -> {
                val ctx = context ?: run { callback(null, "Not initialized"); return }
                NotificationManagerCompat.from(ctx).cancelAll()
                callback(null, null)
            }
            else -> callback(null, "Unknown method: $method")
        }
    }
}
