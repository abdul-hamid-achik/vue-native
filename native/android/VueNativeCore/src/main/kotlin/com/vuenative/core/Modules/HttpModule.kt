package com.vuenative.core

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

        /** Client with certificate pinning — rebuilt when pins are configured. */
        @Volatile private var pinnedClient: OkHttpClient? = null

        fun client(): OkHttpClient = pinnedClient ?: defaultClient

        fun configurePins(pinsMap: Map<String, List<String>>) {
            val builder = CertificatePinner.Builder()
            for ((domain, pins) in pinsMap) {
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
