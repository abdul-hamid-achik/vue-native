package com.vuenative.core

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkInfo
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowNetworkInfo

/**
 * Regression coverage for the API-level guard in [NetworkModule.getStatus].
 *
 * `ConnectivityManager.getActiveNetwork()` only exists on API 23+, while the
 * library's minSdk is 21. It was called unguarded from `dispatchStatus`, which
 * runs on ConnectivityManager's own binder thread with no try/catch — so on an
 * API 21/22 device it threw `NoSuchMethodError`, an `Error` that no
 * `catch (e: Exception)` upstream (including NativeModuleRegistry.invoke) could
 * stop, killing the process.
 */
@RunWith(RobolectricTestRunner::class)
class NetworkModuleApiGuardTest {

    private val module = NetworkModule()

    private fun connectivityManager(): ConnectivityManager {
        val context = ApplicationProvider.getApplicationContext<Context>()
        return context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }

    @Suppress("DEPRECATION")
    private fun setActiveNetworkInfo(cm: ConnectivityManager, info: NetworkInfo) {
        @Suppress("DEPRECATION")
        shadowOf(cm).setActiveNetworkInfo(info)
    }

    @Test
    @Config(sdk = [21])
    fun doesNotCallGetActiveNetworkBelowApi23() {
        // Under Robolectric at SDK 21 the framework class genuinely has no
        // getActiveNetwork(), so simply reaching this assertion reproduces the
        // production NoSuchMethodError rather than testing a value.
        val cm = connectivityManager()
        setActiveNetworkInfo(
            cm,
            ShadowNetworkInfo.newInstance(
                NetworkInfo.DetailedState.DISCONNECTED,
                ConnectivityManager.TYPE_MOBILE,
                0,
                false,
                false,
            ),
        )

        val status = module.getStatus(cm)

        assertEquals(false, status["isConnected"])
        assertEquals("none", status["connectionType"])
    }

    @Test
    @Config(sdk = [21])
    fun legacyPathReportsWifiFromActiveNetworkInfo() {
        val cm = connectivityManager()
        setActiveNetworkInfo(
            cm,
            ShadowNetworkInfo.newInstance(
                NetworkInfo.DetailedState.CONNECTED,
                ConnectivityManager.TYPE_WIFI,
                0,
                true,
                true,
            ),
        )

        val status = module.getStatus(cm)

        assertEquals(true, status["isConnected"])
        assertEquals("wifi", status["connectionType"])
    }

    @Test
    @Config(sdk = [21])
    fun legacyPathReportsCellularFromActiveNetworkInfo() {
        val cm = connectivityManager()
        setActiveNetworkInfo(
            cm,
            ShadowNetworkInfo.newInstance(
                NetworkInfo.DetailedState.CONNECTED,
                ConnectivityManager.TYPE_MOBILE,
                0,
                true,
                true,
            ),
        )

        assertEquals("cellular", module.getStatus(cm)["connectionType"])
    }

    @Test
    @Config(sdk = [34])
    fun api23PathIsWellFormedOnModernDevices() {
        val status = module.getStatus(connectivityManager())

        assertEquals(setOf("isConnected", "connectionType"), status.keys)
        assertEquals(true, status["isConnected"] is Boolean)
        assertEquals(true, status["connectionType"] is String)
    }
}
