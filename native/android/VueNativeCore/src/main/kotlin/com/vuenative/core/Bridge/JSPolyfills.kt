package com.vuenative.core

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.eclipsesource.v8.JavaCallback
import com.eclipsesource.v8.JavaVoidCallback
import com.eclipsesource.v8.V8Array
import com.eclipsesource.v8.V8Object
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import org.json.JSONObject
import java.io.IOException
import java.security.SecureRandom

/**
 * Registers browser-like APIs in the V8 context.
 * Must be called from the JS thread after V8 is initialized.
 */
object JSPolyfills {

    private const val TAG = "VueNative-Polyfills"
    private val mainHandler = Handler(Looper.getMainLooper())
    private val httpClient = OkHttpClient()

    // Timer storage — accessed from JS thread only
    private val timers = mutableMapOf<Int, Runnable>()
    private var nextTimerId = 1

    // RAF — accessed from JS thread only
    private val rafCallbacks = mutableMapOf<Int, Any>()
    private var nextRafId = 1
    private var rafChoreographerPosted = false

    fun register(runtime: JSRuntime) {
        runtime.runOnJsThread {
            val v8 = runtime.v8() ?: return@runOnJsThread
            registerConsole(runtime)
            registerTimers(runtime)
            registerMicrotask(runtime)
            registerRAF(runtime)
            registerPerformance(runtime)
            registerGlobalThis(runtime)
            registerFetch(runtime)
            registerBase64(runtime)
            registerTextEncoding(runtime)
            registerURL(runtime)
            registerCrypto(runtime)
        }
    }

    /** Reset all timers, RAF callbacks, and counters. Call before hot-reloading a new bundle. */
    fun reset() {
        // Cancel all pending timer callbacks
        for ((_, runnable) in timers) {
            mainHandler.removeCallbacks(runnable)
        }
        timers.clear()

        // Clear RAF state
        rafCallbacks.clear()
        rafChoreographerPosted = false

        // Reset counters
        nextTimerId = 1
        nextRafId = 1
    }

    // -- console ------------------------------------------------------------------

    private fun registerConsole(runtime: JSRuntime) {
        runtime.runOnJsThread {
            val v8 = runtime.v8() ?: return@runOnJsThread
            v8.executeVoidScript("var console = {};")

            listOf("log", "warn", "error", "debug", "info").forEach { level ->
                v8.registerJavaMethod(JavaVoidCallback { _, params ->
                    try {
                        val msg = if (params.length() == 0) "undefined"
                                  else params.get(0)?.toString() ?: "null"
                        when (level) {
                            "error" -> Log.e("VueNative JS", msg)
                            "warn"  -> Log.w("VueNative JS", msg)
                            else    -> Log.d("VueNative JS", msg)
                        }
                    } finally {
                        params.close()
                    }
                }, "__console_$level")
            }

            v8.executeVoidScript("""
                console.log   = function() { __console_log(Array.prototype.join.call(arguments,' ')); };
                console.warn  = function() { __console_warn(Array.prototype.join.call(arguments,' ')); };
                console.error = function() { __console_error(Array.prototype.join.call(arguments,' ')); };
                console.debug = function() { __console_debug(Array.prototype.join.call(arguments,' ')); };
                console.info  = function() { __console_info(Array.prototype.join.call(arguments,' ')); };
            """)
        }
    }

    // -- setTimeout / clearTimeout / setInterval / clearInterval ------------------

    private fun registerTimers(runtime: JSRuntime) {
        runtime.runOnJsThread {
            val v8 = runtime.v8() ?: return@runOnJsThread

            // setTimeout(fn, delay) -> timerId
            v8.registerJavaMethod(JavaCallback { _, params ->
                try {
                    val timerId = nextTimerId++
                    val delayMs = if (params.length() > 1) params.getDouble(1).toLong() else 0L

                    // Post to main thread which posts back to JS thread after delay
                    val runnable = Runnable {
                        runtime.runOnJsThread {
                            try {
                                v8.executeVoidScript(
                                    "if(typeof __vnTimerCb_$timerId==='function'){" +
                                    "var f=__vnTimerCb_$timerId;" +
                                    "delete __vnTimerCb_$timerId;" +
                                    "f();}"
                                )
                            } catch (e: Exception) {
                                Log.e(TAG, "Timer callback error", e)
                            } finally {
                                timers.remove(timerId)
                            }
                        }
                    }
                    timers[timerId] = runnable
                    mainHandler.postDelayed(runnable, delayMs.coerceAtLeast(1L))

                    return@JavaCallback timerId
                } finally {
                    params.close()
                }
            }, "__vnSetTimeout")

            // clearTimeout(timerId)
            v8.registerJavaMethod(JavaVoidCallback { _, params ->
                try {
                    val id = params.getInteger(0)
                    timers.remove(id)?.let { mainHandler.removeCallbacks(it) }
                    v8.executeVoidScript("delete __vnTimerCb_$id")
                } finally {
                    params.close()
                }
            }, "__vnClearTimeout")

            // setInterval(fn, delay) -> timerId
            v8.registerJavaMethod(JavaCallback { _, params ->
                try {
                    val timerId = nextTimerId++
                    val delayMs = if (params.length() > 1) params.getDouble(1).toLong() else 0L

                    fun scheduleNext() {
                        val runnable = Runnable {
                            runtime.runOnJsThread {
                                try {
                                    val active = v8.executeBooleanScript(
                                        "!!__vnIntervalActive_$timerId"
                                    )
                                    if (active) {
                                        v8.executeVoidScript(
                                            "if(typeof __vnIntervalCb_$timerId==='function')" +
                                            "__vnIntervalCb_$timerId()"
                                        )
                                        scheduleNext()
                                    } else {
                                        timers.remove(timerId)
                                    }
                                } catch (e: Exception) {
                                    Log.e(TAG, "Interval callback error", e)
                                }
                            }
                        }
                        timers[timerId] = runnable
                        mainHandler.postDelayed(runnable, delayMs.coerceAtLeast(1L))
                    }
                    scheduleNext()
                    return@JavaCallback timerId
                } finally {
                    params.close()
                }
            }, "__vnSetInterval")

            v8.registerJavaMethod(JavaVoidCallback { _, params ->
                try {
                    val id = params.getInteger(0)
                    timers.remove(id)?.let { mainHandler.removeCallbacks(it) }
                    v8.executeVoidScript("__vnIntervalActive_$id = false; delete __vnIntervalCb_$id")
                } finally {
                    params.close()
                }
            }, "__vnClearInterval")

            // Expose standard names via JS wrapper
            v8.executeVoidScript("""
                function setTimeout(fn, delay) {
                    var id = __vnSetTimeout(fn, delay || 0);
                    this['__vnTimerCb_' + id] = fn;
                    return id;
                }
                function clearTimeout(id) { __vnClearTimeout(id); }
                function setInterval(fn, delay) {
                    var id = __vnSetInterval(fn, delay || 0);
                    this['__vnIntervalCb_' + id] = fn;
                    this['__vnIntervalActive_' + id] = true;
                    return id;
                }
                function clearInterval(id) { __vnClearInterval(id); }
            """)
        }
    }

    // -- queueMicrotask -----------------------------------------------------------

    private fun registerMicrotask(runtime: JSRuntime) {
        runtime.runOnJsThread {
            val v8 = runtime.v8() ?: return@runOnJsThread
            // V8 has native Promise support — use it for microtasks
            v8.executeVoidScript("""
                function queueMicrotask(callback) {
                    Promise.resolve().then(callback);
                }
            """)
        }
    }

    // -- requestAnimationFrame / cancelAnimationFrame -----------------------------

    private fun registerRAF(runtime: JSRuntime) {
        runtime.runOnJsThread {
            val v8 = runtime.v8() ?: return@runOnJsThread

            v8.registerJavaMethod(JavaCallback { _, params ->
                try {
                    val rafId = nextRafId++
                    rafCallbacks[rafId] = true

                    if (!rafChoreographerPosted) {
                        rafChoreographerPosted = true
                        postRAFChoreographer(runtime)
                    }
                    return@JavaCallback rafId
                } finally {
                    params.close()
                }
            }, "__vnRequestRAF")

            v8.registerJavaMethod(JavaVoidCallback { _, params ->
                try {
                    val id = params.getInteger(0)
                    rafCallbacks.remove(id)
                    v8.executeVoidScript("delete __vnRafCb_$id")
                } finally {
                    params.close()
                }
            }, "__vnCancelRAF")

            v8.executeVoidScript("""
                function requestAnimationFrame(fn) {
                    var id = __vnRequestRAF(fn);
                    this['__vnRafCb_' + id] = fn;
                    return id;
                }
                function cancelAnimationFrame(id) { __vnCancelRAF(id); }
            """)
        }
    }

    private fun postRAFChoreographer(runtime: JSRuntime) {
        mainHandler.post {
            val now = System.currentTimeMillis()
            runtime.runOnJsThread {
                val v8 = runtime.v8() ?: return@runOnJsThread
                try {
                    // Fire all pending RAF callbacks
                    v8.executeVoidScript("""
                        (function() {
                            var keys = Object.keys(this).filter(function(k){ return k.startsWith('__vnRafCb_'); });
                            var cbs = {};
                            keys.forEach(function(k){ cbs[k] = this[k]; delete this[k]; }.bind(this));
                            keys.forEach(function(k){ if(typeof cbs[k]==='function') cbs[k]($now); });
                        }).call(this);
                    """)
                    // Check if more RAF callbacks were registered
                    val hasMore = v8.executeBooleanScript(
                        "Object.keys(this).some(function(k){ return k.startsWith('__vnRafCb_'); })"
                    )
                    if (hasMore) {
                        postRAFChoreographer(runtime)
                    } else {
                        rafChoreographerPosted = false
                    }
                } catch (e: Exception) {
                    rafChoreographerPosted = false
                    Log.e(TAG, "RAF error", e)
                }
            }
        }
    }

    // -- performance.now() --------------------------------------------------------

    private fun registerPerformance(runtime: JSRuntime) {
        runtime.runOnJsThread {
            val v8 = runtime.v8() ?: return@runOnJsThread
            v8.executeVoidScript("var performance = {};")
            v8.registerJavaMethod(JavaCallback { _, params ->
                try {
                    return@JavaCallback (System.currentTimeMillis() - runtime.startTimeMs).toDouble()
                } finally {
                    params.close()
                }
            }, "__vnPerfNow")
            v8.executeVoidScript("performance.now = function(){ return __vnPerfNow(); };")
        }
    }

    // -- globalThis ---------------------------------------------------------------

    private fun registerGlobalThis(runtime: JSRuntime) {
        runtime.runOnJsThread {
            val v8 = runtime.v8() ?: return@runOnJsThread
            v8.executeVoidScript("""
                if (typeof globalThis === 'undefined') {
                    var globalThis = this;
                }
            """)
        }
    }

    // -- fetch --------------------------------------------------------------------
    // Uses per-request IDs to support concurrent fetch() calls safely.

    private fun registerFetch(runtime: JSRuntime) {
        runtime.runOnJsThread {
            val v8 = runtime.v8() ?: return@runOnJsThread

            // __vnFetch(url, optsJson, requestId) — requestId is echoed back to JS callbacks
            v8.registerJavaMethod(JavaVoidCallback { _, params ->
                val url: String
                val optsJson: String
                val requestId: Int
                try {
                    url = params.getString(0)
                    optsJson = if (params.length() > 1 && params.getType(1) == 4) params.getString(1) else "{}"
                    requestId = if (params.length() > 2) params.getDouble(2).toInt() else 0
                } finally {
                    params.close()
                }
                val opts = try { JSONObject(optsJson) } catch (e: Exception) { JSONObject() }

                val method = opts.optString("method", "GET").uppercase()
                val bodyStr = opts.optString("body", "")
                val headersObj = opts.optJSONObject("headers")

                val builder = Request.Builder().url(url)
                headersObj?.keys()?.forEach { k -> builder.addHeader(k, headersObj.getString(k)) }

                val requestBody = if (bodyStr.isNotEmpty()) {
                    val ct = headersObj?.optString("Content-Type") ?: "application/json"
                    bodyStr.toRequestBody(ct.toMediaTypeOrNull())
                } else if (method != "GET" && method != "HEAD") {
                    "".toRequestBody()
                } else null

                builder.method(method, requestBody)

                httpClient.newCall(builder.build()).enqueue(object : Callback {
                    override fun onFailure(call: Call, e: IOException) {
                        val errMsg = e.message ?: "Network error"
                        runtime.runOnJsThread {
                            v8.executeVoidScript(
                                "__vnFetchReject($requestId,${JSONObject.quote(errMsg)})"
                            )
                        }
                    }
                    override fun onResponse(call: Call, response: Response) {
                        val status = response.code
                        val ok = status in 200..299
                        val body = response.body?.string() ?: ""
                        val hdrs = JSONObject()
                        response.headers.forEach { (k, v) -> hdrs.put(k, v) }
                        val resp = JSONObject().apply {
                            put("status", status)
                            put("ok", ok)
                            put("_body", body)
                            put("headers", hdrs)
                        }
                        val respJson = JSONObject.quote(resp.toString())
                        runtime.runOnJsThread {
                            v8.executeVoidScript("__vnFetchResolve($requestId,$respJson)")
                        }
                    }
                })
            }, "__vnFetch")

            v8.executeVoidScript("""
                var __vnFetchCallbacks = {};
                var __vnFetchNextId = 1;

                function fetch(url, options) {
                    return new Promise(function(resolve, reject) {
                        var id = __vnFetchNextId++;
                        __vnFetchCallbacks[id] = { resolve: resolve, reject: reject };
                        __vnFetch(url, options ? JSON.stringify(options) : '{}', id);
                    });
                }

                function __vnFetchResolve(id, respJson) {
                    var cb = __vnFetchCallbacks[id];
                    if (!cb) return;
                    delete __vnFetchCallbacks[id];
                    var resp = JSON.parse(respJson) || {};
                    resp.text = function() { return Promise.resolve(resp._body || ''); };
                    resp.json = function() {
                        return new Promise(function(res, rej) {
                            try { res(JSON.parse(resp._body || '{}')); }
                            catch(e) { rej(e); }
                        });
                    };
                    cb.resolve(resp);
                }

                function __vnFetchReject(id, msg) {
                    var cb = __vnFetchCallbacks[id];
                    if (!cb) return;
                    delete __vnFetchCallbacks[id];
                    cb.reject(new Error(msg));
                }
            """)
        }
    }

    // -- atob / btoa (Base64) -----------------------------------------------------

    private fun registerBase64(runtime: JSRuntime) {
        runtime.runOnJsThread {
            val v8 = runtime.v8() ?: return@runOnJsThread

            // atob — decode base64 string to plain text
            v8.registerJavaMethod(JavaCallback { _, params ->
                try {
                    val encoded = params.getString(0)
                    val decoded = android.util.Base64.decode(encoded, android.util.Base64.DEFAULT)
                    return@JavaCallback String(decoded, Charsets.UTF_8)
                } catch (e: Exception) {
                    Log.e(TAG, "atob error", e)
                    return@JavaCallback ""
                } finally {
                    params.close()
                }
            }, "__vnAtob")

            // btoa — encode plain text to base64 string
            v8.registerJavaMethod(JavaCallback { _, params ->
                try {
                    val str = params.getString(0)
                    val encoded = android.util.Base64.encodeToString(
                        str.toByteArray(Charsets.UTF_8),
                        android.util.Base64.NO_WRAP
                    )
                    return@JavaCallback encoded
                } catch (e: Exception) {
                    Log.e(TAG, "btoa error", e)
                    return@JavaCallback ""
                } finally {
                    params.close()
                }
            }, "__vnBtoa")

            v8.executeVoidScript("""
                function atob(encoded) { return __vnAtob(encoded); }
                function btoa(str) { return __vnBtoa(str); }
            """)
        }
    }

    // -- TextEncoder / TextDecoder ------------------------------------------------

    private fun registerTextEncoding(runtime: JSRuntime) {
        runtime.runOnJsThread {
            val v8 = runtime.v8() ?: return@runOnJsThread
            v8.executeVoidScript("""
                class TextEncoder {
                    constructor(encoding) { this.encoding = encoding || 'utf-8'; }
                    encode(str) {
                        var arr = [];
                        for (var i = 0; i < str.length; i++) {
                            var c = str.charCodeAt(i);
                            if (c < 0x80) { arr.push(c); }
                            else if (c < 0x800) { arr.push(0xc0 | (c >> 6), 0x80 | (c & 0x3f)); }
                            else if (c < 0xd800 || c >= 0xe000) { arr.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f)); }
                            else { i++; c = 0x10000 + (((c & 0x3ff) << 10) | (str.charCodeAt(i) & 0x3ff)); arr.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 0x3f), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f)); }
                        }
                        return new Uint8Array(arr);
                    }
                }
                class TextDecoder {
                    constructor(encoding) { this.encoding = encoding || 'utf-8'; }
                    decode(buffer) {
                        var bytes = buffer instanceof Uint8Array ? buffer : new Uint8Array(buffer);
                        var result = '';
                        for (var i = 0; i < bytes.length;) {
                            var c = bytes[i++];
                            if (c < 0x80) { result += String.fromCharCode(c); }
                            else if (c < 0xe0) { result += String.fromCharCode(((c & 0x1f) << 6) | (bytes[i++] & 0x3f)); }
                            else if (c < 0xf0) { result += String.fromCharCode(((c & 0x0f) << 12) | ((bytes[i++] & 0x3f) << 6) | (bytes[i++] & 0x3f)); }
                            else { var cp = ((c & 0x07) << 18) | ((bytes[i++] & 0x3f) << 12) | ((bytes[i++] & 0x3f) << 6) | (bytes[i++] & 0x3f); result += String.fromCodePoint(cp); }
                        }
                        return result;
                    }
                }
                if (typeof globalThis !== 'undefined') {
                    globalThis.TextEncoder = TextEncoder;
                    globalThis.TextDecoder = TextDecoder;
                }
            """)
        }
    }

    // -- URL / URLSearchParams ----------------------------------------------------

    private fun registerURL(runtime: JSRuntime) {
        runtime.runOnJsThread {
            val v8 = runtime.v8() ?: return@runOnJsThread
            v8.executeVoidScript("""
                if (typeof URL === 'undefined') {
                    var URL = (function() {
                        function URL(url, base) {
                            if (base) {
                                if (!url.match(/^[a-zA-Z]+:/)) {
                                    var b = new URL(base);
                                    url = b.origin + (url.charAt(0) === '/' ? '' : '/') + url;
                                }
                            }
                            var match = url.match(/^([a-zA-Z]+:)\/\/([^\/:]+)(:\d+)?(\/[^?#]*)?(\?[^#]*)?(#.*)?$/);
                            if (!match) { this.href = url; this.protocol = ''; this.host = ''; this.hostname = ''; this.port = ''; this.pathname = '/'; this.search = ''; this.hash = ''; this.origin = ''; this.searchParams = new URLSearchParams(''); return; }
                            this.protocol = match[1] || '';
                            this.hostname = match[2] || '';
                            this.port = (match[3] || '').slice(1);
                            this.host = this.hostname + (this.port ? ':' + this.port : '');
                            this.pathname = match[4] || '/';
                            this.search = match[5] || '';
                            this.hash = match[6] || '';
                            this.origin = this.protocol + '//' + this.host;
                            this.href = url;
                            this.searchParams = new URLSearchParams(this.search);
                        }
                        URL.prototype.toString = function() { return this.href; };
                        return URL;
                    })();
                    if (typeof globalThis !== 'undefined') globalThis.URL = URL;
                }
                if (typeof URLSearchParams === 'undefined') {
                    var URLSearchParams = (function() {
                        function URLSearchParams(init) {
                            this._params = [];
                            if (typeof init === 'string') {
                                var parts = init.replace(/^\?/, '').split('&');
                                for (var i = 0; i < parts.length; i++) {
                                    if (!parts[i]) continue;
                                    var eq = parts[i].indexOf('=');
                                    if (eq === -1) { this._params.push([decodeURIComponent(parts[i]), '']); }
                                    else { this._params.push([decodeURIComponent(parts[i].slice(0, eq)), decodeURIComponent(parts[i].slice(eq + 1))]); }
                                }
                            }
                        }
                        URLSearchParams.prototype.get = function(name) {
                            for (var i = 0; i < this._params.length; i++) { if (this._params[i][0] === name) return this._params[i][1]; }
                            return null;
                        };
                        URLSearchParams.prototype.getAll = function(name) {
                            var r = [];
                            for (var i = 0; i < this._params.length; i++) { if (this._params[i][0] === name) r.push(this._params[i][1]); }
                            return r;
                        };
                        URLSearchParams.prototype.has = function(name) {
                            for (var i = 0; i < this._params.length; i++) { if (this._params[i][0] === name) return true; }
                            return false;
                        };
                        URLSearchParams.prototype.set = function(name, value) { this.delete(name); this._params.push([name, String(value)]); };
                        URLSearchParams.prototype.append = function(name, value) { this._params.push([name, String(value)]); };
                        URLSearchParams.prototype.delete = function(name) {
                            this._params = this._params.filter(function(p) { return p[0] !== name; });
                        };
                        URLSearchParams.prototype.toString = function() {
                            return this._params.map(function(p) { return encodeURIComponent(p[0]) + '=' + encodeURIComponent(p[1]); }).join('&');
                        };
                        URLSearchParams.prototype.forEach = function(cb) {
                            for (var i = 0; i < this._params.length; i++) { cb(this._params[i][1], this._params[i][0], this); }
                        };
                        return URLSearchParams;
                    })();
                    if (typeof globalThis !== 'undefined') globalThis.URLSearchParams = URLSearchParams;
                }
            """)
        }
    }

    // -- crypto.getRandomValues ---------------------------------------------------

    private fun registerCrypto(runtime: JSRuntime) {
        runtime.runOnJsThread {
            val v8 = runtime.v8() ?: return@runOnJsThread

            // Native method: __vnGetRandomValues(length) -> comma-separated byte string
            v8.registerJavaMethod(JavaCallback { _, params ->
                try {
                    val length = params.getInteger(0)
                    if (length <= 0) return@JavaCallback ""
                    val bytes = ByteArray(length)
                    SecureRandom().nextBytes(bytes)
                    return@JavaCallback bytes.joinToString(",") { (it.toInt() and 0xFF).toString() }
                } catch (e: Exception) {
                    Log.e(TAG, "crypto.getRandomValues error", e)
                    return@JavaCallback ""
                } finally {
                    params.close()
                }
            }, "__vnGetRandomValues")

            v8.executeVoidScript("""
                if (typeof crypto === 'undefined') {
                    var crypto = {};
                    if (typeof globalThis !== 'undefined') globalThis.crypto = crypto;
                }
                crypto.getRandomValues = function(typedArray) {
                    var len = typedArray.length;
                    if (len > 0) {
                        var csv = __vnGetRandomValues(len);
                        if (csv) {
                            var vals = csv.split(',');
                            for (var i = 0; i < len; i++) {
                                typedArray[i] = parseInt(vals[i], 10);
                            }
                        }
                    }
                    return typedArray;
                };
            """)
        }
    }
}
