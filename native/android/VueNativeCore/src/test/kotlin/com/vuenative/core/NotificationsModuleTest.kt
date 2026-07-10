package com.vuenative.core

import android.Manifest
import android.app.Activity
import android.app.Application
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Looper
import android.widget.FrameLayout
import androidx.test.core.app.ApplicationProvider
import java.util.concurrent.TimeUnit
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class NotificationsModuleTest {
    private lateinit var application: Application
    private lateinit var activity: Activity
    private lateinit var bridge: NativeBridge
    private lateinit var registry: NativeModuleRegistry
    private lateinit var permissions: PermissionsModule
    private lateinit var notifications: NotificationsModule

    @Before
    fun setUp() {
        val registryField = NativeModuleRegistry::class.java.getDeclaredField("instance")
        registryField.isAccessible = true
        registryField.set(null, null)

        application = ApplicationProvider.getApplicationContext()
        application.getSharedPreferences("vue_native_permissions", Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
        shadowOf(application).denyPermissions(Manifest.permission.POST_NOTIFICATIONS)

        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        bridge = NativeBridge(activity).also { it.hostContainer = FrameLayout(activity) }
        registry = NativeModuleRegistry.getInstance(activity)
        permissions = PermissionsModule()
        notifications = NotificationsModule()
        assertTrue(registry.registerAndInitialize(permissions, bridge, activity))
        assertTrue(registry.registerAndInitialize(notifications, bridge, activity))
        PermissionsModule.setActivity(activity)
    }

    @After
    fun tearDown() {
        registry.destroyAll()
        PermissionsModule.setActivity(null)
        PermissionsModule.pendingCallbacks.clear()
    }

    @Test
    fun requestPermissionUsesActivityRouterAndReturnsBoolean() {
        var result: Any? = "pending"
        var callbackError: String? = "pending"

        notifications.invoke("requestPermission", emptyList(), bridge) { value, error ->
            result = value
            callbackError = error
        }

        val request = shadowOf(activity).lastRequestedPermission
        assertNotNull(request)
        assertArrayEquals(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            request.requestedPermissions,
        )
        assertEquals("pending", result)
        assertTrue(PermissionsModule.pendingCallbacks.containsKey(request.requestCode))

        PermissionsModule.onPermissionsResult(
            request.requestCode,
            request.requestedPermissions,
            intArrayOf(PackageManager.PERMISSION_GRANTED),
        )

        assertEquals(true, result)
        assertNull(callbackError)
        assertTrue(PermissionsModule.pendingCallbacks.isEmpty())
    }

    @Test
    fun permissionStatusTracksNotDeterminedAndDeniedStates() {
        var status: Any? = null
        var requestResult: Any? = "pending"
        var requestError: String? = "pending"
        notifications.invoke("getPermissionStatus", emptyList(), bridge) { value, error ->
            assertNull(error)
            status = value
        }
        assertEquals("notDetermined", status)

        notifications.invoke("requestPermission", emptyList(), bridge) { value, error ->
            requestResult = value
            requestError = error
        }
        val request = shadowOf(activity).lastRequestedPermission
        PermissionsModule.onPermissionsResult(
            request.requestCode,
            request.requestedPermissions,
            intArrayOf(PackageManager.PERMISSION_DENIED),
        )
        assertEquals(false, requestResult)
        assertNull(requestError)

        notifications.invoke("getPermissionStatus", emptyList(), bridge) { value, error ->
            assertNull(error)
            status = value
        }
        assertEquals("denied", status)
    }

    @Test
    fun destroyingModuleRejectsItsPendingPermissionRequest() {
        var callbackError: String? = null
        notifications.invoke("requestPermission", emptyList(), bridge) { _, error ->
            callbackError = error
        }
        assertTrue(PermissionsModule.pendingCallbacks.isNotEmpty())

        notifications.destroy()

        assertTrue(PermissionsModule.pendingCallbacks.isEmpty())
        assertTrue(callbackError?.contains("host was destroyed") == true)
    }

    @Test
    @Config(sdk = [32])
    fun permissionIsImplicitlyGrantedBeforeAndroid13() {
        var requested: Any? = null
        var status: Any? = null

        notifications.invoke("requestPermission", emptyList(), bridge) { value, error ->
            assertNull(error)
            requested = value
        }
        notifications.invoke("getPermissionStatus", emptyList(), bridge) { value, error ->
            assertNull(error)
            status = value
        }

        assertEquals(true, requested)
        assertEquals("granted", status)
    }

    @Test
    fun scheduleReturnsStringIdAndCancelUsesTheSameId() {
        shadowOf(application).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        val notificationManager = activity.getSystemService(NotificationManager::class.java)
        val shadowNotifications = shadowOf(notificationManager)
        var notificationId: Any? = null

        notifications.invoke(
            "scheduleLocal",
            listOf(mapOf("title" to "Reminder", "body" to "Stretch")),
            bridge,
        ) { value, error ->
            assertNull(error)
            notificationId = value
        }

        assertTrue(notificationId is String)
        val id = notificationId as String
        assertTrue(id.isNotBlank())
        assertNotNull(shadowNotifications.getNotification(id, 1))

        var cancelError: String? = "pending"
        notifications.invoke("cancel", listOf(id), bridge) { _, error -> cancelError = error }
        assertNull(cancelError)
        assertNull(shadowNotifications.getNotification(id, 1))
    }

    @Test
    fun customIdCanCancelADelayedNotificationBeforeDelivery() {
        shadowOf(application).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        val notificationManager = activity.getSystemService(NotificationManager::class.java)
        val shadowNotifications = shadowOf(notificationManager)
        var returnedId: Any? = null

        notifications.invoke(
            "scheduleLocal",
            listOf(
                mapOf(
                    "id" to "scheduled-reminder",
                    "title" to "Reminder",
                    "body" to "Stretch",
                    "delay" to 5,
                ),
            ),
            bridge,
        ) { value, error ->
            assertNull(error)
            returnedId = value
        }
        notifications.invoke("cancel", listOf("scheduled-reminder"), bridge) { _, error ->
            assertNull(error)
        }

        shadowOf(Looper.getMainLooper()).idleFor(6, TimeUnit.SECONDS)

        assertEquals("scheduled-reminder", returnedId)
        assertNull(shadowNotifications.getNotification("scheduled-reminder", 1))
    }
}
