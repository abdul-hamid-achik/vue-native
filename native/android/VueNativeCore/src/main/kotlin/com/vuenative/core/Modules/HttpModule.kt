package com.vuenative.core

import android.util.Base64
import android.util.Log
import java.io.IOException
import java.util.concurrent.TimeUnit
import okhttp3.CertificatePinner
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject

/**
 * HttpModule — backs the useHttp() composable.
 * Provides a request() method that handles arbitrary HTTP calls from JS with
 * support for baseURL, custom headers, all HTTP methods, and certificate pinning.
 */
class HttpModule : NativeModule {
    override val moduleName = "Http"

    companion object {
        /** Default client without certificate pinning. */
        private val defaultClient = OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build()

        private val pinLock = Any()
        private val pinMap = linkedMapOf<String, List<String>>()

        private const val PIN_PREFIX = "sha256/"

        /**
         * Deprecated SHA-1 pins. Android accepted them through OkHttp before
         * 0.23.0, and rejecting them in 0.23.0 refused every connection to a host
         * pinned only with sha1/. They are accepted again with a warning; Apple
         * platforms have never accepted them.
         */
        private const val LEGACY_SHA1_PIN_PREFIX = "sha1/"
        private const val TAG = "VueNative.Http"

        /**
         * A pin no certificate can match (32 zero bytes). It is stored for a host
         * whose pins were all malformed and had nothing valid to fall back on, so
         * the pinning check fails every connection to that host.
         */
        private val REFUSE_ALL_PIN = PIN_PREFIX + Base64.encodeToString(ByteArray(32), Base64.NO_WRAP)

        /** Client with certificate pinning — rebuilt when pins are configured. */
        @Volatile private var pinnedClient: OkHttpClient? = null

        fun client(): OkHttpClient = pinnedClient ?: defaultClient

        /**
         * Merge pin lists into the process-wide map (Apple semantics).
         *
         * An empty list removes the host's pins. A non-empty list keeps only its
         * valid `sha256/<base64>` pins (and deprecated `sha1/<base64>` ones, with a
         * warning). When none are valid, the host keeps its
         * previous pins; a host with no previous pins is refused instead of being
         * left unpinned, so a typo cannot silently disable pinning. Rebuilds the
         * shared client.
         */
        fun configurePins(pinsMap: Map<String, List<String>>) {
            synchronized(pinLock) {
                for ((domain, pins) in pinsMap) {
                    val host = domain.lowercase()
                    if (pins.isEmpty()) {
                        pinMap.remove(host)
                        continue
                    }
                    val valid = pins.filter { isValidPin(it) }
                    if (valid.any { it.startsWith(LEGACY_SHA1_PIN_PREFIX) }) {
                        Log.w(
                            TAG,
                            "Certificate pins for '$host' use deprecated sha1/ hashes. They work on " +
                                "Android only; use sha256/ pins, which every platform accepts.",
                        )
                    }
                    when {
                        valid.isNotEmpty() -> pinMap[host] = valid
                        pinMap[host] == null -> pinMap[host] = listOf(REFUSE_ALL_PIN)
                    }
                }
                rebuildPinnedClient()
            }
        }

        private fun isValidPin(pin: String): Boolean {
            val prefix = when {
                pin.startsWith(PIN_PREFIX) -> PIN_PREFIX
                pin.startsWith(LEGACY_SHA1_PIN_PREFIX) -> LEGACY_SHA1_PIN_PREFIX
                else -> return false
            }
            val encoded = pin.substring(prefix.length)
            return try {
                encoded.isNotEmpty() && Base64.decode(encoded, Base64.DEFAULT).isNotEmpty()
            } catch (e: IllegalArgumentException) {
                false
            }
        }

        internal fun pinnedHosts(): Set<String> = synchronized(pinLock) { pinMap.keys.toSet() }

        internal fun pinsFor(host: String): List<String>? = synchronized(pinLock) { pinMap[host.lowercase()] }

        internal fun resetPins() {
            synchronized(pinLock) {
                pinMap.clear()
                pinnedClient = null
            }
        }

        private fun rebuildPinnedClient() {
            if (pinMap.isEmpty()) {
                pinnedClient = null
                return
            }
            val builder = CertificatePinner.Builder()
            for ((domain, pins) in pinMap) {
                for (pin in pins) {
                    builder.add(domain, pin)
                }
            }
            pinnedClient = defaultClient.newBuilder()
                .certificatePinner(builder.build())
                .build()
        }
    }

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit
    ) {
        when (method) {
            "configurePins" -> {
                val pinsMap = parsePins(args.getOrNull(0))
                    ?: run {
                        callback(null, "Invalid args — expected pins object")
                        return
                    }

                configurePins(pinsMap)
                callback(true, null)
            }
            "request" -> {
                val opts = args.getOrNull(0) as? Map<*, *>
                    ?: run {
                        callback(null, "Invalid args — expected options object")
                        return
                    }

                val url = opts["url"]?.toString()
                    ?: run {
                        callback(null, "Missing required field: url")
                        return
                    }
                val baseURL = opts["baseURL"]?.toString() ?: ""
                val httpMethod = opts["method"]?.toString()?.uppercase() ?: "GET"
                val body = opts["body"]?.toString() ?: ""
                @Suppress("UNCHECKED_CAST")
                val headers = opts["headers"] as? Map<String, String>

                val fullUrl = if (url.startsWith("http")) url else "$baseURL$url"

                val builder = Request.Builder().url(fullUrl)
                headers?.forEach { (k, v) -> builder.addHeader(k, v) }

                val contentType = headers?.get("Content-Type")
                    ?: headers?.get("content-type")
                    ?: "application/json"

                val requestBody = when {
                    body.isNotEmpty() -> body.toRequestBody(contentType.toMediaTypeOrNull())
                    httpMethod != "GET" && httpMethod != "HEAD" -> "".toRequestBody()
                    else -> null
                }
                builder.method(httpMethod, requestBody)

                client().newCall(builder.build()).enqueue(object : okhttp3.Callback {
                    override fun onFailure(call: okhttp3.Call, e: IOException) {
                        callback(null, e.message ?: "Network error")
                    }

                    override fun onResponse(call: okhttp3.Call, response: okhttp3.Response) {
                        val responseBody = response.body?.string() ?: ""
                        val responseHeaders = mutableMapOf<String, String>()
                        response.headers.forEach { (k, v) -> responseHeaders[k] = v }
                        callback(
                            mapOf(
                                "status" to response.code,
                                "ok" to (response.code in 200..299),
                                "data" to responseBody,
                                "headers" to responseHeaders
                            ), null
                        )
                    }
                })
            }
            else -> callback(null, "Unknown method: $method")
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun parsePins(value: Any?): Map<String, List<String>>? {
        return when (value) {
            is Map<*, *> -> value.mapValues { (_, pins) ->
                when (pins) {
                    is List<*> -> pins.mapNotNull { it?.toString() }
                    is JSONArray -> (0 until pins.length()).mapNotNull { pins.optString(it, null) }
                    else -> return null
                }
            } as? Map<String, List<String>>
            is JSONObject -> {
                val result = mutableMapOf<String, List<String>>()
                val keys = value.keys()
                while (keys.hasNext()) {
                    val domain = keys.next()
                    val pins = value.optJSONArray(domain) ?: return null
                    result[domain] = (0 until pins.length()).mapNotNull { pins.optString(it, null) }
                }
                result
            }
            else -> null
        }
    }
}
