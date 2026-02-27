package com.vuenative.core

import android.content.Context
import android.widget.FrameLayout
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class NativeModuleTest {

    private lateinit var context: Context
    private lateinit var bridge: NativeBridge

    @Before
    fun setUp() {
        // Reset singletons
        val crField = ComponentRegistry::class.java.getDeclaredField("instance")
        crField.isAccessible = true
        crField.set(null, null)

        val nmrField = NativeModuleRegistry::class.java.getDeclaredField("instance")
        nmrField.isAccessible = true
        nmrField.set(null, null)

        context = ApplicationProvider.getApplicationContext()
        bridge = NativeBridge(context)
        bridge.hostContainer = FrameLayout(context)
    }

    // =========================================================================
    // HapticsModule
    // =========================================================================

    @Test
    fun testHapticsModuleName() {
        val module = HapticsModule()
        assertEquals("Haptics", module.moduleName)
    }

    @Test
    fun testHapticsModuleInitialize() {
        val module = HapticsModule()
        // Should not throw in Robolectric
        module.initialize(context, bridge)
    }

    @Test
    fun testHapticsModuleVibrateDoesNotCrash() {
        val module = HapticsModule()
        module.initialize(context, bridge)

        var resultError: String? = "not_called"
        module.invoke("vibrate", listOf("medium"), bridge) { _, error ->
            resultError = error
        }
        assertNull("vibrate should not produce error", resultError)
    }

    @Test
    fun testHapticsModuleSelectionChanged() {
        val module = HapticsModule()
        module.initialize(context, bridge)

        var resultError: String? = "not_called"
        module.invoke("selectionChanged", emptyList(), bridge) { _, error ->
            resultError = error
        }
        assertNull("selectionChanged should not produce error", resultError)
    }

    @Test
    fun testHapticsModuleUnknownMethod() {
        val module = HapticsModule()
        module.initialize(context, bridge)

        var resultError: String? = null
        module.invoke("nonexistent", emptyList(), bridge) { _, error ->
            resultError = error
        }
        assertNotNull("Unknown method should produce error", resultError)
        assertTrue("Error should mention method", resultError!!.contains("Unknown method"))
    }

    // =========================================================================
    // ClipboardModule
    // =========================================================================

    @Test
    fun testClipboardModuleName() {
        val module = ClipboardModule()
        assertEquals("Clipboard", module.moduleName)
    }

    @Test
    fun testClipboardModuleSetAndGetString() {
        val module = ClipboardModule()
        module.initialize(context, bridge)

        // Set
        var setError: String? = "not_called"
        module.invoke("setString", listOf("Hello Clipboard"), bridge) { _, error ->
            setError = error
        }
        assertNull("setString should not produce error", setError)

        // Get
        var gotValue: Any? = null
        module.invoke("getString", emptyList(), bridge) { result, _ ->
            gotValue = result
        }
        assertEquals("Hello Clipboard", gotValue)
    }

    @Test
    fun testClipboardModuleHasString() {
        val module = ClipboardModule()
        module.initialize(context, bridge)

        module.invoke("setString", listOf("test"), bridge) { _, _ -> }

        var hasString: Any? = null
        module.invoke("hasString", emptyList(), bridge) { result, _ ->
            hasString = result
        }
        assertEquals(true, hasString)
    }

    @Test
    fun testClipboardModuleUnknownMethod() {
        val module = ClipboardModule()
        module.initialize(context, bridge)

        var error: String? = null
        module.invoke("nonexistent", emptyList(), bridge) { _, err ->
            error = err
        }
        assertNotNull("Unknown method should produce error", error)
    }

    // =========================================================================
    // DeviceInfoModule
    // =========================================================================

    @Test
    fun testDeviceInfoModuleName() {
        val module = DeviceInfoModule()
        assertEquals("DeviceInfo", module.moduleName)
    }

    @Test
    fun testDeviceInfoModuleReturnsInfo() {
        val module = DeviceInfoModule()
        module.initialize(context, bridge)

        var result: Any? = null
        module.invoke("getDeviceInfo", emptyList(), bridge) { res, _ ->
            result = res
        }

        assertNotNull("getDeviceInfo should return data", result)
        @Suppress("UNCHECKED_CAST")
        val info = result as Map<String, Any>
        assertEquals("android", info["platform"])
        assertEquals("Android", info["systemName"])
        assertNotNull("model should be present", info["model"])
        assertNotNull("screenWidth should be present", info["screenWidth"])
        assertNotNull("screenHeight should be present", info["screenHeight"])
        assertNotNull("screenScale should be present", info["screenScale"])
        assertNotNull("bundleId should be present", info["bundleId"])
    }

    @Test
    fun testDeviceInfoModuleGetInfo() {
        val module = DeviceInfoModule()
        module.initialize(context, bridge)

        var result: Any? = null
        module.invoke("getInfo", emptyList(), bridge) { res, _ ->
            result = res
        }

        assertNotNull("getInfo should return data", result)
    }

    @Test
    fun testDeviceInfoModuleUnknownMethod() {
        val module = DeviceInfoModule()
        module.initialize(context, bridge)

        var error: String? = null
        module.invoke("nonexistent", emptyList(), bridge) { _, err ->
            error = err
        }
        assertNotNull(error)
    }

    // =========================================================================
    // AsyncStorageModule
    // =========================================================================

    @Test
    fun testAsyncStorageModuleName() {
        val module = AsyncStorageModule()
        assertEquals("AsyncStorage", module.moduleName)
    }

    @Test
    fun testAsyncStorageSetAndGetItem() {
        val module = AsyncStorageModule()
        module.initialize(context, bridge)

        // Set
        var setError: String? = "not_called"
        module.invoke("setItem", listOf("testKey", "testValue"), bridge) { _, error ->
            setError = error
        }
        assertNull("setItem should not produce error", setError)

        // Get
        var result: Any? = null
        module.invoke("getItem", listOf("testKey"), bridge) { res, _ ->
            result = res
        }
        assertEquals("testValue", result)
    }

    @Test
    fun testAsyncStorageRemoveItem() {
        val module = AsyncStorageModule()
        module.initialize(context, bridge)

        module.invoke("setItem", listOf("key1", "value1"), bridge) { _, _ -> }

        module.invoke("removeItem", listOf("key1"), bridge) { _, _ -> }

        var result: Any? = "not_null"
        module.invoke("getItem", listOf("key1"), bridge) { res, _ ->
            result = res
        }
        assertNull("Value should be null after removeItem", result)
    }

    @Test
    fun testAsyncStorageClear() {
        val module = AsyncStorageModule()
        module.initialize(context, bridge)

        module.invoke("setItem", listOf("k1", "v1"), bridge) { _, _ -> }
        module.invoke("setItem", listOf("k2", "v2"), bridge) { _, _ -> }

        module.invoke("clear", emptyList(), bridge) { _, _ -> }

        var result: Any? = "not_null"
        module.invoke("getItem", listOf("k1"), bridge) { res, _ ->
            result = res
        }
        assertNull("Value should be null after clear", result)
    }

    @Test
    fun testAsyncStorageGetAllKeys() {
        val module = AsyncStorageModule()
        module.initialize(context, bridge)

        // Clear first
        module.invoke("clear", emptyList(), bridge) { _, _ -> }

        module.invoke("setItem", listOf("alpha", "1"), bridge) { _, _ -> }
        module.invoke("setItem", listOf("beta", "2"), bridge) { _, _ -> }

        var keys: Any? = null
        module.invoke("getAllKeys", emptyList(), bridge) { res, _ ->
            keys = res
        }

        assertNotNull("getAllKeys should return list", keys)
        @Suppress("UNCHECKED_CAST")
        val keyList = keys as List<String>
        assertTrue("Keys should contain 'alpha'", keyList.contains("alpha"))
        assertTrue("Keys should contain 'beta'", keyList.contains("beta"))
    }

    @Test
    fun testAsyncStorageMissingKeyError() {
        val module = AsyncStorageModule()
        module.initialize(context, bridge)

        var error: String? = null
        module.invoke("getItem", emptyList(), bridge) { _, err ->
            error = err
        }
        assertNotNull("Missing key should produce error", error)
        assertTrue("Error should mention key", error!!.contains("key", ignoreCase = true))
    }

    @Test
    fun testAsyncStorageUnknownMethod() {
        val module = AsyncStorageModule()
        module.initialize(context, bridge)

        var error: String? = null
        module.invoke("nonexistent", emptyList(), bridge) { _, err ->
            error = err
        }
        assertNotNull(error)
    }

    // =========================================================================
    // AnimationModule
    // =========================================================================

    @Test
    fun testAnimationModuleName() {
        val module = AnimationModule()
        assertEquals("Animation", module.moduleName)
    }

    @Test
    fun testAnimationModuleUnknownMethod() {
        val module = AnimationModule()
        module.initialize(context, bridge)

        var error: String? = null
        module.invoke("nonexistent", emptyList(), bridge) { _, err ->
            error = err
        }
        assertNotNull("Unknown animation method should produce error", error)
        assertTrue(error!!.contains("Unknown animation method"))
    }

    // =========================================================================
    // NetworkModule
    // =========================================================================

    @Test
    fun testNetworkModuleName() {
        val module = NetworkModule()
        assertEquals("Network", module.moduleName)
    }

    @Test
    fun testNetworkModuleGetStatus() {
        val module = NetworkModule()
        module.initialize(context, bridge)

        var result: Any? = null
        module.invoke("getStatus", emptyList(), bridge) { res, _ ->
            result = res
        }

        assertNotNull("getStatus should return data", result)
        @Suppress("UNCHECKED_CAST")
        val status = result as Map<String, Any>
        assertTrue("Status should contain isConnected", status.containsKey("isConnected"))
        assertTrue("Status should contain connectionType", status.containsKey("connectionType"))
    }

    @Test
    fun testNetworkModuleUnknownMethod() {
        val module = NetworkModule()
        module.initialize(context, bridge)

        var error: String? = null
        module.invoke("nonexistent", emptyList(), bridge) { _, err ->
            error = err
        }
        assertNotNull(error)
    }

    @Test
    fun testNetworkModuleDestroy() {
        val module = NetworkModule()
        module.initialize(context, bridge)
        // Should not crash
        module.destroy()
    }

    // =========================================================================
    // KeyboardModule
    // =========================================================================

    @Test
    fun testKeyboardModuleName() {
        val module = KeyboardModule()
        assertEquals("Keyboard", module.moduleName)
    }

    @Test
    fun testKeyboardModuleDismiss() {
        val module = KeyboardModule()
        module.initialize(context, bridge)

        var error: String? = "not_called"
        module.invoke("dismiss", emptyList(), bridge) { _, err ->
            error = err
        }
        assertNull("dismiss should not produce error", error)
    }

    @Test
    fun testKeyboardModuleGetHeight() {
        val module = KeyboardModule()
        module.initialize(context, bridge)

        var result: Any? = null
        module.invoke("getKeyboardHeight", emptyList(), bridge) { res, _ ->
            result = res
        }
        assertEquals(0, result)
    }

    @Test
    fun testKeyboardModuleUnknownMethod() {
        val module = KeyboardModule()
        module.initialize(context, bridge)

        var error: String? = null
        module.invoke("nonexistent", emptyList(), bridge) { _, err ->
            error = err
        }
        assertNotNull(error)
    }

    // =========================================================================
    // NativeModule interface defaults
    // =========================================================================

    @Test
    fun testNativeModuleDefaultInvokeSync() {
        val module = object : NativeModule {
            override val moduleName = "TestDefault"
            override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
                callback(null, null)
            }
        }

        val result = module.invokeSync("test", emptyList(), bridge)
        assertNull("Default invokeSync should return null", result)
    }

    @Test
    fun testNativeModuleDefaultInitialize() {
        val module = object : NativeModule {
            override val moduleName = "TestDefault"
            override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
                callback(null, null)
            }
        }

        // Default initialize should not crash
        module.initialize(context, bridge)
    }

    @Test
    fun testNativeModuleDefaultDestroy() {
        val module = object : NativeModule {
            override val moduleName = "TestDefault"
            override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
                callback(null, null)
            }
        }

        // Default destroy should not crash
        module.destroy()
    }
}
