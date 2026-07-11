package com.vuenative.core

import android.Manifest
import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.pm.PackageManager
import android.widget.FrameLayout
import androidx.test.core.app.ApplicationProvider
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
class PermissionsModuleTest {
    private lateinit var application: Application
    private lateinit var activity: Activity
    private lateinit var bridge: NativeBridge
    private lateinit var permissions: PermissionsModule

    @Before
    fun setUp() {
        application = ApplicationProvider.getApplicationContext()
        application.getSharedPreferences("vue_native_permissions", Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
        shadowOf(application).denyPermissions(Manifest.permission.POST_NOTIFICATIONS)

        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        bridge = NativeBridge(activity).also { it.hostContainer = FrameLayout(activity) }
        permissions = PermissionsModule().also { it.initialize(activity, bridge) }
        PermissionsModule.setActivity(activity)
        PermissionsModule.pendingCallbacks.clear()
    }

    @After
    fun tearDown() {
        permissions.destroy()
        PermissionsModule.setActivity(null)
        PermissionsModule.pendingCallbacks.clear()
    }

    @Test
    @Config(sdk = [32])
    fun notificationsAreImplicitlyGrantedBeforeAndroid13() {
        var checked: Any? = null
        var requested: Any? = null

        permissions.invoke("check", listOf("notifications"), bridge) { value, error ->
            assertNull(error)
            checked = value
        }
        permissions.invoke("request", listOf("notifications"), bridge) { value, error ->
            assertNull(error)
            requested = value
        }

        assertEquals("granted", checked)
        assertEquals("granted", requested)
        assertNull(shadowOf(activity).lastRequestedPermission)
        assertTrue(PermissionsModule.pendingCallbacks.isEmpty())
    }

    @Test
    @Config(sdk = [33])
    fun notificationsRemainRuntimePermissionOnAndroid13() {
        var checked: Any? = null
        var requested: Any? = "pending"

        permissions.invoke("check", listOf("notifications"), bridge) { value, error ->
            assertNull(error)
            checked = value
        }
        permissions.invoke("request", listOf("notifications"), bridge) { value, error ->
            assertNull(error)
            requested = value
        }

        assertEquals("notDetermined", checked)
        assertEquals("pending", requested)
        val request = shadowOf(activity).lastRequestedPermission
        assertNotNull(request)
        assertArrayEquals(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            request.requestedPermissions,
        )
        assertTrue(PermissionsModule.pendingCallbacks.containsKey(request.requestCode))

        PermissionsModule.onPermissionsResult(
            request.requestCode,
            request.requestedPermissions,
            intArrayOf(PackageManager.PERMISSION_DENIED),
        )

        assertEquals("denied", requested)
        assertTrue(PermissionsModule.pendingCallbacks.isEmpty())
    }
}
