package com.vuenative.core

import android.app.Activity
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.After
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class NativeHostLifecycleTest {

    private lateinit var context: Context
    private lateinit var bridge: NativeBridge

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        bridge = NativeBridge(context)
        PermissionsModule.pendingCallbacks.clear()
    }

    @After
    fun tearDown() {
        NotificationsModule.instance?.destroy()
        PermissionsModule.pendingCallbacks.clear()
    }

    @Test
    fun notificationsDestroyClearsProcessSingleton() {
        val module = NotificationsModule()
        module.initialize(context, bridge)
        assertSame(module, NotificationsModule.instance)

        module.destroy()

        assertNull(NotificationsModule.instance)
    }

    @Test
    fun activityOwningModulesReleaseHostContextOnDestroy() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val modules = listOf<NativeModule>(SocialAuthModule(), IAPModule())

        modules.forEach { module ->
            module.initialize(activity, bridge)
            val contextField = module.javaClass.getDeclaredField("context")
            contextField.isAccessible = true
            assertSame(activity, contextField.get(module))

            module.destroy()

            assertNull(contextField.get(module))
        }
    }

    @Test
    fun permissionsDestroyResolvesAndClearsPendingCallbacks() {
        val module = PermissionsModule()
        var callbackError: String? = null
        PermissionsModule.pendingCallbacks[9_100] = { _, error -> callbackError = error }

        module.destroy()

        assertTrue(PermissionsModule.pendingCallbacks.isEmpty())
        assertTrue(callbackError?.contains("host was destroyed") == true)
    }

    @Test
    fun nestedJsThreadRegistrationRunsSynchronously() {
        val runtime = JSRuntime(context)
        val completed = CountDownLatch(1)
        var nestedRanBeforeCompletion = false

        runtime.runOnJsThread {
            runtime.runOnJsThread {
                nestedRanBeforeCompletion = true
            }
            completed.countDown()
        }

        assertTrue(completed.await(2, TimeUnit.SECONDS))
        assertTrue(nestedRanBeforeCompletion)
        runtime.release()
    }
}
