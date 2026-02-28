package com.vuenative.core

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class HotReloadManagerTest {

    private lateinit var context: Context
    private var lastReloadCode: String? = null
    private lateinit var manager: HotReloadManager

    @Before
    fun setUp() {
        // Reset ComponentRegistry singleton via reflection
        val crField = ComponentRegistry::class.java.getDeclaredField("instance")
        crField.isAccessible = true
        crField.set(null, null)

        // Reset NativeModuleRegistry singleton via reflection
        val nmrField = NativeModuleRegistry::class.java.getDeclaredField("instance")
        nmrField.isAccessible = true
        nmrField.set(null, null)

        context = ApplicationProvider.getApplicationContext()
        lastReloadCode = null

        val runtime = JSRuntime(context)
        manager = HotReloadManager(runtime) { code ->
            lastReloadCode = code
        }
    }

    // -------------------------------------------------------------------------
    // Initialization
    // -------------------------------------------------------------------------

    @Test
    fun testCreation() {
        assertNotNull("HotReloadManager should be created", manager)
    }

    // -------------------------------------------------------------------------
    // Initial connection state is disconnected
    // -------------------------------------------------------------------------

    @Test
    fun testInitialConnectionState() {
        val field = HotReloadManager::class.java.getDeclaredField("isConnected")
        field.isAccessible = true
        val connected = field.getBoolean(manager)
        assertFalse("Should not be connected initially", connected)
    }

    // -------------------------------------------------------------------------
    // disconnect() clears state
    // -------------------------------------------------------------------------

    @Test
    fun testDisconnect() {
        manager.disconnect()

        val connField = HotReloadManager::class.java.getDeclaredField("isConnected")
        connField.isAccessible = true
        assertFalse("isConnected should be false after disconnect", connField.getBoolean(manager))

        val devField = HotReloadManager::class.java.getDeclaredField("devServerUrl")
        devField.isAccessible = true
        val devUrl = devField.get(manager)
        assertTrue("devServerUrl should be null after disconnect", devUrl == null)

        val bundleField = HotReloadManager::class.java.getDeclaredField("bundleUrl")
        bundleField.isAccessible = true
        val bundleUrl = bundleField.get(manager)
        assertTrue("bundleUrl should be null after disconnect", bundleUrl == null)

        val wsField = HotReloadManager::class.java.getDeclaredField("wsSession")
        wsField.isAccessible = true
        val ws = wsField.get(manager)
        assertTrue("wsSession should be null after disconnect", ws == null)
    }

    // -------------------------------------------------------------------------
    // disconnect() is idempotent
    // -------------------------------------------------------------------------

    @Test
    fun testDisconnectIdempotent() {
        manager.disconnect()
        manager.disconnect()
        manager.disconnect()
        // Should not throw
        assertTrue(true)
    }

    // -------------------------------------------------------------------------
    // connect() stores URLs
    // -------------------------------------------------------------------------

    @Test
    fun testConnectStoresUrls() {
        manager.connect("ws://localhost:3000", "http://localhost:3000/bundle.js")

        val devField = HotReloadManager::class.java.getDeclaredField("devServerUrl")
        devField.isAccessible = true
        val devUrl = devField.get(manager) as? String
        assertTrue("devServerUrl should be set", devUrl == "ws://localhost:3000")

        val bundleField = HotReloadManager::class.java.getDeclaredField("bundleUrl")
        bundleField.isAccessible = true
        val bundleUrl = bundleField.get(manager) as? String
        assertTrue("bundleUrl should be set", bundleUrl == "http://localhost:3000/bundle.js")

        manager.disconnect()
    }

    // -------------------------------------------------------------------------
    // After disconnect, can reconnect
    // -------------------------------------------------------------------------

    @Test
    fun testReconnectAfterDisconnect() {
        manager.connect("ws://localhost:3000", "http://localhost:3000/bundle.js")
        manager.disconnect()

        // Scope and job should be fresh after disconnect
        val scopeJobField = HotReloadManager::class.java.getDeclaredField("scopeJob")
        scopeJobField.isAccessible = true
        val scopeJob = scopeJobField.get(manager) as kotlinx.coroutines.Job
        assertFalse("scopeJob should not be cancelled after disconnect+reinit", scopeJob.isCancelled)

        manager.connect("ws://localhost:4000", "http://localhost:4000/bundle.js")

        val devField = HotReloadManager::class.java.getDeclaredField("devServerUrl")
        devField.isAccessible = true
        val devUrl = devField.get(manager) as? String
        assertTrue("devServerUrl should be updated", devUrl == "ws://localhost:4000")

        manager.disconnect()
    }

    // -------------------------------------------------------------------------
    // httpClient exists
    // -------------------------------------------------------------------------

    @Test
    fun testHttpClientExists() {
        val field = HotReloadManager::class.java.getDeclaredField("httpClient")
        field.isAccessible = true
        val client = field.get(manager)
        assertNotNull("httpClient should not be null", client)
    }
}
