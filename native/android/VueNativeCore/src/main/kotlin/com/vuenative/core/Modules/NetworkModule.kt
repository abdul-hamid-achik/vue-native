package com.vuenative.core

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build

class NetworkModule : NativeModule {
    override val moduleName = "Network"
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var bridge: NativeBridge? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.bridge = bridge
        connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        startMonitoring(bridge)
    }

    private fun startMonitoring(bridge: NativeBridge) {
        val cm = connectivityManager ?: return
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                dispatchStatus(cm, bridge)
            }
            override fun onLost(network: Network) {
                bridge.dispatchGlobalEvent("network:change", mapOf(
                    "isConnected" to false, "connectionType" to "none"
                ))
            }
            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                dispatchStatus(cm, bridge)
            }
        }
        networkCallback = cb
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            cm.registerDefaultNetworkCallback(cb)
        } else {
            val req = NetworkRequest.Builder().build()
            cm.registerNetworkCallback(req, cb)
        }
    }

    private fun dispatchStatus(cm: ConnectivityManager, bridge: NativeBridge) {
        val info = getStatus(cm)
        bridge.dispatchGlobalEvent("network:change", info)
    }

    private fun getStatus(cm: ConnectivityManager): Map<String, Any> {
        val network = cm.activeNetwork
        val caps = network?.let { cm.getNetworkCapabilities(it) }
        val isConnected = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
        val type = when {
            caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true -> "wifi"
            caps?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true -> "cellular"
            caps?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true -> "ethernet"
            else -> "none"
        }
        return mapOf("isConnected" to isConnected, "connectionType" to type)
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val cm = connectivityManager ?: run { callback(mapOf("isConnected" to false, "connectionType" to "none"), null); return }
        when (method) {
            "getStatus" -> callback(getStatus(cm), null)
            else -> callback(null, "Unknown method: $method")
        }
    }

    override fun destroy() {
        networkCallback?.let { connectivityManager?.unregisterNetworkCallback(it) }
    }
}
