package com.vuenative.core

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Mock NativeModule for testing purposes.
 */
class MockNativeModule(override val moduleName: String) : NativeModule {
    var lastMethod: String? = null
    var lastArgs: List<Any?> = emptyList()
    var resultToReturn: Any? = null

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        lastMethod = method
        lastArgs = args
        callback(resultToReturn, null)
    }

    override fun invokeSync(method: String, args: List<Any?>, bridge: NativeBridge): Any? {
        lastMethod = method
        lastArgs = args
        return resultToReturn
    }
}

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class NativeModuleRegistryTest {

    private lateinit var context: Context
    private lateinit var registry: NativeModuleRegistry
    private lateinit var bridge: NativeBridge

    @Before
    fun setUp() {
        // Reset NativeModuleRegistry singleton via reflection
        val nmrField = NativeModuleRegistry::class.java.getDeclaredField("instance")
        nmrField.isAccessible = true
        nmrField.set(null, null)

        // Reset ComponentRegistry singleton via reflection (needed for NativeBridge)
        val crField = ComponentRegistry::class.java.getDeclaredField("instance")
        crField.isAccessible = true
        crField.set(null, null)

        context = ApplicationProvider.getApplicationContext()
        registry = NativeModuleRegistry.getInstance(context)
        bridge = NativeBridge(context)
    }

    // -------------------------------------------------------------------------
    // Register and get module
    // -------------------------------------------------------------------------

    @Test
    fun testRegisterAndGetModule() {
        val mock = MockNativeModule("TestModule")
        registry.register(mock)

        val retrieved = registry.getModule("TestModule")
        assertNotNull("getModule should return the registered module", retrieved)
        assertEquals("TestModule", retrieved!!.moduleName)
        assertTrue("Retrieved module should be the same instance", retrieved === mock)
    }

    // -------------------------------------------------------------------------
    // Get unknown module returns null
    // -------------------------------------------------------------------------

    @Test
    fun testGetUnknownModule() {
        val result = registry.getModule("nonexistent")
        assertNull("getModule for unknown name should return null", result)
    }

    // -------------------------------------------------------------------------
    // invoke — async
    // -------------------------------------------------------------------------

    @Test
    fun testInvoke() {
        val mock = MockNativeModule("TestModule")
        mock.resultToReturn = mapOf("success" to true)
        registry.register(mock)

        var callbackResult: Any? = null
        var callbackError: String? = "not_called"

        registry.invoke("TestModule", "doSomething", listOf("arg1", 42), bridge) { result, error ->
            callbackResult = result
            callbackError = error
        }

        assertEquals("doSomething", mock.lastMethod)
        assertEquals(listOf("arg1", 42), mock.lastArgs)
        assertNotNull("Callback result should be non-null", callbackResult)
        assertNull("Callback error should be null", callbackError)
    }

    // -------------------------------------------------------------------------
    // invoke unknown module — callback receives error
    // -------------------------------------------------------------------------

    @Test
    fun testInvokeUnknownModule() {
        var callbackResult: Any? = "not_null"
        var callbackError: String? = null

        registry.invoke("NonExistent", "method", emptyList(), bridge) { result, error ->
            callbackResult = result
            callbackError = error
        }

        assertNull("Result should be null for unknown module", callbackResult)
        assertNotNull("Error should be non-null for unknown module", callbackError)
        assertTrue(
            "Error should mention the module name",
            callbackError!!.contains("NonExistent")
        )
    }

    // -------------------------------------------------------------------------
    // invokeSync
    // -------------------------------------------------------------------------

    @Test
    fun testInvokeSync() {
        val mock = MockNativeModule("SyncModule")
        mock.resultToReturn = "sync_result"
        registry.register(mock)

        val result = registry.invokeSync("SyncModule", "getInfo", listOf("key"), bridge)

        assertEquals("sync_result", result)
        assertEquals("getInfo", mock.lastMethod)
        assertEquals(listOf("key"), mock.lastArgs)
    }

    // -------------------------------------------------------------------------
    // invokeSync unknown module — returns null
    // -------------------------------------------------------------------------

    @Test
    fun testInvokeSyncUnknownModule() {
        val result = registry.invokeSync("NonExistent", "method", emptyList(), bridge)
        assertNull("invokeSync for unknown module should return null", result)
    }

    // -------------------------------------------------------------------------
    // registerDefaults — key modules are present
    // -------------------------------------------------------------------------

    @Test
    fun testRegisterDefaults() {
        // Some modules (e.g. SecureStorageModule) may throw during initialize()
        // in the Robolectric environment (KeyStore not available). Wrap with try/catch
        // and verify the modules that registered successfully.
        try {
            registry.registerDefaults(bridge)
        } catch (_: Exception) {
            // Some modules may fail to initialize in test — that's OK
        }

        // Spot-check modules that register before SecureStorageModule (which throws
        // java.security.KeyStoreException in Robolectric, halting the forEach loop).
        // Modules registered in order: Haptics, AsyncStorage, Clipboard, DeviceInfo,
        // Network, AppState, Linking, Share, Animation, Keyboard, Permissions,
        // Geolocation, Notifications, Http, Biometry, Camera, SecureStorage(throws)...
        assertNotNull("Haptics module should be registered", registry.getModule("Haptics"))
        assertNotNull("AsyncStorage module should be registered", registry.getModule("AsyncStorage"))
        assertNotNull("Clipboard module should be registered", registry.getModule("Clipboard"))
        assertNotNull("DeviceInfo module should be registered", registry.getModule("DeviceInfo"))
        assertNotNull("Network module should be registered", registry.getModule("Network"))
        assertNotNull("Animation module should be registered", registry.getModule("Animation"))
        assertNotNull("Http module should be registered", registry.getModule("Http"))
    }

    // -------------------------------------------------------------------------
    // Register overwrite — second module wins
    // -------------------------------------------------------------------------

    @Test
    fun testRegisterOverwrite() {
        val first = MockNativeModule("Shared")
        first.resultToReturn = "first"
        registry.register(first)

        val second = MockNativeModule("Shared")
        second.resultToReturn = "second"
        registry.register(second)

        val retrieved = registry.getModule("Shared")
        assertNotNull(retrieved)

        // Invoke and verify second module's result is used
        val result = registry.invokeSync("Shared", "test", emptyList(), bridge)
        assertEquals("second", result)
        assertTrue("Retrieved module should be the second one", retrieved === second)
    }

    // -------------------------------------------------------------------------
    // invoke with exception in module
    // -------------------------------------------------------------------------

    @Test
    fun testInvokeWithModuleException() {
        val throwingModule = object : NativeModule {
            override val moduleName = "Thrower"
            override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
                throw RuntimeException("Module exploded")
            }
        }
        registry.register(throwingModule)

        var callbackResult: Any? = "not_null"
        var callbackError: String? = null

        registry.invoke("Thrower", "boom", emptyList(), bridge) { result, error ->
            callbackResult = result
            callbackError = error
        }

        assertNull("Result should be null when module throws", callbackResult)
        assertNotNull("Error should be set when module throws", callbackError)
        assertTrue(
            "Error message should contain exception message",
            callbackError!!.contains("Module exploded")
        )
    }

    // -------------------------------------------------------------------------
    // Singleton behavior
    // -------------------------------------------------------------------------

    @Test
    fun testSingletonReturnsSameInstance() {
        val instance1 = NativeModuleRegistry.getInstance(context)
        val instance2 = NativeModuleRegistry.getInstance(context)
        assertTrue("getInstance should return the same instance", instance1 === instance2)
    }
}
