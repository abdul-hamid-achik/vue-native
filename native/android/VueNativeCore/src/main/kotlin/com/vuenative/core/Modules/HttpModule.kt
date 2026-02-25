package com.vuenative.core

import java.io.IOException
import java.util.concurrent.TimeUnit
import okhttp3.CertificatePinner
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

/**
 * HttpModule — backs the useHttp() composable.
 * Provides a request() method that handles arbitrary HTTP calls from JS with
 * support for baseURL, custom headers, all HTTP methods, and certificate pinning.
 */
class HttpModule : NativeModule {
    override val moduleName = "Http"

    /** Default client without certificate pinning. */
    private val defaultClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    /** Client with certificate pinning — rebuilt when pins are configured. */
    private var pinnedClient: OkHttpClient? = null

    /** Current certificate pinner, if any. */
    private var certificatePinner: CertificatePinner? = null

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit
    ) {
        when (method) {
            "configurePins" -> {
                @Suppress("UNCHECKED_CAST")
                val pinsMap = args.getOrNull(0) as? Map<String, List<String>>
                    ?: run {
                        callback(null, "Invalid args — expected pins object")
                        return
                    }

                val builder = CertificatePinner.Builder()
                for ((domain, pins) in pinsMap) {
                    for (pin in pins) {
                        // OkHttp expects pins in "sha256/base64hash" format
                        builder.add(domain, pin)
                    }
                }
                certificatePinner = builder.build()
                pinnedClient = defaultClient.newBuilder()
                    .certificatePinner(certificatePinner!!)
                    .build()
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

                // Use pinned client when configured, otherwise default
                val client = pinnedClient ?: defaultClient

                client.newCall(builder.build()).enqueue(object : okhttp3.Callback {
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
}
