package com.vuenative.core

import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mozilla.javascript.BaseFunction
import org.mozilla.javascript.Context
import org.mozilla.javascript.Scriptable
import org.mozilla.javascript.ScriptableObject
import org.mozilla.javascript.Undefined
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows
import org.robolectric.annotation.Config

private const val ROOT_LABEL = "app-shell-root"
private const val LABEL_LABEL = "app-shell-label"
private const val LABEL_TEXT = "app-shell-ok"

class AppShellSmokeActivity : VueNativeActivity() {
    override fun getBundleAssetPath(): String = "app-shell-fixture.js"

    override fun readEmbeddedBundle(): String = loadAppShellFixture()

    internal fun hostRuntime(): JSRuntime = runtime

    internal fun fixtureSource(): String = readEmbeddedBundle()
}

private fun loadAppShellFixture(): String {
    var directory = File(System.getProperty("user.dir") ?: ".")
    repeat(10) {
        val candidate = File(directory, "fixtures/app-shell/vue-native-bundle.js")
        if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
        directory = directory.parentFile ?: return@repeat
    }
    error("fixtures/app-shell/vue-native-bundle.js not found from ${System.getProperty("user.dir")}")
}

/**
 * Evaluate the committed app-shell IIFE on the JVM.
 *
 * Robolectric cannot load J2V8's Android native library, so tests bind
 * `__VN_flushOperations` with Rhino and run the same JavaScript the
 * device/macOS hosts evaluate.
 */
internal fun evaluateAppShellFixture(source: String, flush: (String) -> Unit) {
    val context = Context.enter()
    try {
        context.optimizationLevel = -1
        context.languageVersion = Context.VERSION_ES6
        val scope = context.initStandardObjects()
        val flushFn = object : BaseFunction() {
            override fun call(
                cx: Context,
                scope: Scriptable,
                thisObj: Scriptable,
                args: Array<out Any?>,
            ): Any {
                val json = if (args.isNotEmpty()) Context.toString(args[0]) else "[]"
                flush(json)
                return Undefined.instance
            }
        }
        ScriptableObject.putProperty(scope, "__VN_flushOperations", flushFn)
        context.evaluateString(scope, source, "app-shell-fixture.js", 1, null)
    } finally {
        Context.exit()
    }
}

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class AppShellSmokeTest {

    @Before
    fun setUp() {
        val nativeModuleRegistry = NativeModuleRegistry::class.java.getDeclaredField("instance")
        nativeModuleRegistry.isAccessible = true
        nativeModuleRegistry.set(null, null)

        val componentRegistry = ComponentRegistry::class.java.getDeclaredField("instance")
        componentRegistry.isAccessible = true
        componentRegistry.set(null, null)
    }

    @After
    fun tearDown() {
        val nativeModuleRegistry = NativeModuleRegistry::class.java.getDeclaredField("instance")
        nativeModuleRegistry.isAccessible = true
        nativeModuleRegistry.set(null, null)
    }

    @Test
    fun fixtureJavaScriptFlushesBridgeOperations() {
        val batches = mutableListOf<String>()
        evaluateAppShellFixture(loadAppShellFixture(), batches::add)
        assertEquals(1, batches.size)
        assertTrue(batches.single().contains(ROOT_LABEL))
        assertTrue(batches.single().contains(LABEL_LABEL))
        assertTrue(batches.single().contains(LABEL_TEXT))
    }

    @Test
    fun activityLoadsFixtureAndExposesStableAccessibilityTree() {
        val controller = Robolectric.buildActivity(AppShellSmokeActivity::class.java)
        val activity = controller.get()
        activity.setTheme(androidx.appcompat.R.style.Theme_AppCompat)

        try {
            controller.create()
            drainJsAndMain(activity)
            assertTrue(activity.fixtureSource().contains(ROOT_LABEL))

            evaluateAppShellFixture(activity.fixtureSource()) { json ->
                activity.hostRuntime().bridge.processOperations(json)
            }
            Shadows.shadowOf(Looper.getMainLooper()).idle()

            val root = findByContentDescription(activity.window.decorView, ROOT_LABEL)
            val label = findByContentDescription(activity.window.decorView, LABEL_LABEL)
            assertNotNull("host must attach app-shell-root", root)
            assertNotNull("host must attach app-shell-label", label)
            assertTrue("label must be a descendant of the root", isDescendant(root!!, label!!))
            assertEquals(LABEL_TEXT, (label as TextView).text.toString())
            assertEquals(root, activity.hostRuntime().bridge.rootView)
        } finally {
            controller.destroy()
        }
    }

    private fun drainJsAndMain(activity: AppShellSmokeActivity) {
        val tick = CountDownLatch(1)
        activity.hostRuntime().runOnJsThread { tick.countDown() }
        check(tick.await(2, TimeUnit.SECONDS)) { "JS thread did not drain" }
        Shadows.shadowOf(Looper.getMainLooper()).idle()
    }

    private fun findByContentDescription(view: View, label: String): View? {
        if (view.contentDescription == label) return view
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                findByContentDescription(view.getChildAt(index), label)?.let { return it }
            }
        }
        return null
    }

    private fun isDescendant(ancestor: View, candidate: View): Boolean {
        var current: View? = candidate
        while (current != null) {
            if (current === ancestor) return true
            current = current.parent as? View
        }
        return false
    }
}
