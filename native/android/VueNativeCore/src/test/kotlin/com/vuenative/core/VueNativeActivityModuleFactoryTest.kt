package com.vuenative.core

import android.content.Context
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

private const val CUSTOM_MODULE_NAME = "ActivityCustomModule"

class ActivityCustomModule : NativeModule {
    override val moduleName = CUSTOM_MODULE_NAME
    var initializedContext: Context? = null
    var destroyCount = 0

    override fun initialize(context: Context, bridge: NativeBridge) {
        initializedContext = context
    }

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit,
    ) {
        callback(null, "Unknown method: $method")
    }

    override fun destroy() {
        destroyCount += 1
    }
}

class NativeModuleFactoryTestActivity : VueNativeActivity() {
    val createdModules = mutableListOf<ActivityCustomModule>()

    override fun getBundleAssetPath(): String = "missing-test-bundle.js"

    override fun createNativeModules(): List<NativeModule> =
        listOf(ActivityCustomModule().also(createdModules::add))
}

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class VueNativeActivityModuleFactoryTest {

    @Before
    fun setUp() {
        val nativeModuleRegistry = NativeModuleRegistry::class.java.getDeclaredField("instance")
        nativeModuleRegistry.isAccessible = true
        nativeModuleRegistry.set(null, null)

        val componentRegistry = ComponentRegistry::class.java.getDeclaredField("instance")
        componentRegistry.isAccessible = true
        componentRegistry.set(null, null)
    }

    @Test
    fun customModuleIsFreshForStartupAndHotReload() {
        val controller = Robolectric.buildActivity(NativeModuleFactoryTestActivity::class.java)
        val activity = controller.get()
        activity.setTheme(androidx.appcompat.R.style.Theme_AppCompat)

        try {
            controller.create()
            val registry = NativeModuleRegistry.getInstance(activity)

            assertEquals(1, activity.createdModules.size)
            val startupModule = activity.createdModules.single()
            assertSame(startupModule, registry.getModule(CUSTOM_MODULE_NAME))
            assertSame(activity, startupModule.initializedContext)

            assertTrue(activity.resetNativeModulesForHotReload())

            assertEquals(2, activity.createdModules.size)
            val hotReloadModule = activity.createdModules.last()
            assertNotSame(startupModule, hotReloadModule)
            assertEquals(1, startupModule.destroyCount)
            assertSame(hotReloadModule, registry.getModule(CUSTOM_MODULE_NAME))
            assertSame(activity, hotReloadModule.initializedContext)
        } finally {
            controller.destroy()
        }
    }
}
