package com.vuenative.core

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.AnimatorSet
import android.animation.Keyframe
import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.AccelerateInterpolator
import android.view.animation.DecelerateInterpolator
import android.view.animation.LinearInterpolator

class AnimationModule : NativeModule {
    override val moduleName = "Animation"
    private var context: Context? = null
    private var bridge: NativeBridge? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context
        this.bridge = bridge
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        when (method) {
            "timing" -> handleTiming(args, bridge, callback)
            "spring" -> handleSpring(args, bridge, callback)
            "keyframe" -> handleKeyframe(args, bridge, callback)
            "sequence" -> handleSequence(args, bridge, callback)
            "parallel" -> handleParallel(args, bridge, callback)
            "fadeIn" -> {
                val nodeId = StyleEngine.toInt(args.getOrNull(0), -1)
                val view = bridge.nodeViews[nodeId] ?: run {
                    callback(null, null)
                    return
                }
                mainHandler.post {
                    view.alpha = 0f
                    view.visibility = View.VISIBLE
                    view.animate().alpha(1f).setDuration(300).withEndAction { callback(null, null) }.start()
                }
            }
            "fadeOut" -> {
                val nodeId = StyleEngine.toInt(args.getOrNull(0), -1)
                val view = bridge.nodeViews[nodeId] ?: run {
                    callback(null, null)
                    return
                }
                mainHandler.post {
                    view.animate().alpha(0f).setDuration(300).withEndAction {
                        view.visibility = View.INVISIBLE
                        callback(null, null)
                    }.start()
                }
            }
            else -> callback(null, "Unknown animation method: $method")
        }
    }

    // ── timing(viewId, toStyles, options) ──────────────────────────────────
    // args[0]: nodeId (Int)
    // args[1]: toStyles map { "opacity": 1, "translateX": 100 }
    // args[2]: options { duration, delay, easing }

    private fun handleTiming(args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val nodeId = StyleEngine.toInt(args.getOrNull(0), -1)
        val toStyles = toStringKeyMap(args.getOrNull(1)) ?: emptyMap()
        val options = toStringKeyMap(args.getOrNull(2)) ?: emptyMap()

        val duration = StyleEngine.toInt(options["duration"], 300).toLong()
        val delay = StyleEngine.toInt(options["delay"], 0).toLong()
        val easing = options["easing"]?.toString() ?: "easeInOut"

        val view = bridge.nodeViews[nodeId] ?: run {
            callback(null, "timing: view $nodeId not found")
            return
        }

        mainHandler.post {
            val animators = buildPropertyAnimators(view, toStyles)
            if (animators.isEmpty()) {
                callback(true, null)
                return@post
            }

            val interpolator = resolveInterpolator(easing)
            val set = AnimatorSet()
            set.playTogether(animators)
            set.duration = duration
            set.startDelay = delay
            set.interpolator = interpolator
            set.addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(a: Animator) {
                    callback(true, null)
                }
            })
            set.start()
        }
    }

    // ── spring(viewId, toStyles, options) ──────────────────────────────────
    // args[0]: nodeId
    // args[1]: toStyles map
    // args[2]: options { damping/tension/friction, duration, delay }

    private fun handleSpring(args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val nodeId = StyleEngine.toInt(args.getOrNull(0), -1)
        val toStyles = toStringKeyMap(args.getOrNull(1)) ?: emptyMap()
        val options = toStringKeyMap(args.getOrNull(2)) ?: emptyMap()

        val duration = StyleEngine.toInt(options["duration"], 500).toLong()
        val delay = StyleEngine.toInt(options["delay"], 0).toLong()

        val view = bridge.nodeViews[nodeId] ?: run {
            callback(null, "spring: view $nodeId not found")
            return
        }

        mainHandler.post {
            val animators = buildPropertyAnimators(view, toStyles)
            if (animators.isEmpty()) {
                callback(true, null)
                return@post
            }

            // Android doesn't have built-in spring for ObjectAnimator pre-API 23 DynamicAnimation.
            // Use overshoot interpolator to approximate spring feel.
            val set = AnimatorSet()
            set.playTogether(animators)
            set.duration = duration
            set.startDelay = delay
            set.interpolator = android.view.animation.OvershootInterpolator(1.5f)
            set.addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(a: Animator) {
                    callback(true, null)
                }
            })
            set.start()
        }
    }

    // ── keyframe(viewId, keyframeSteps, options) ───────────────────────────
    // args[0]: nodeId
    // args[1]: List<Map> keyframe steps [{ offset: 0.0, opacity: 1 }, ...]
    // args[2]: options { duration }

    private fun handleKeyframe(args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val nodeId = StyleEngine.toInt(args.getOrNull(0), -1)
        val stepsRaw = args.getOrNull(1) as? List<*> ?: run {
            callback(null, "keyframe: invalid keyframes")
            return
        }
        val options = toStringKeyMap(args.getOrNull(2)) ?: emptyMap()
        val duration = StyleEngine.toInt(options["duration"], 300).toLong()

        val view = bridge.nodeViews[nodeId] ?: run {
            callback(null, "keyframe: view $nodeId not found")
            return
        }

        // Parse keyframe steps into Map<String, List<Pair<Float, Float>>> (property -> [(offset, value)])
        val propertyKeyframes = mutableMapOf<String, MutableList<Pair<Float, Float>>>()
        for (raw in stepsRaw) {
            val step = toStringKeyMap(raw) ?: continue
            val offset = StyleEngine.toFloat(step["offset"], 0f)
            for ((key, value) in step) {
                if (key == "offset") continue
                val floatVal = StyleEngine.toFloat(value, Float.NaN)
                if (floatVal.isNaN()) continue
                propertyKeyframes.getOrPut(key) { mutableListOf() }.add(offset to floatVal)
            }
        }

        if (propertyKeyframes.isEmpty()) {
            callback(null, null)
            return
        }

        mainHandler.post {
            val animators = mutableListOf<Animator>()

            for ((propKey, frames) in propertyKeyframes) {
                val androidProps = mapPropertyName(propKey)
                for (androidProp in androidProps) {
                    val kfs = frames.map { (offset, value) ->
                        Keyframe.ofFloat(offset, value)
                    }.toTypedArray()
                    val pvh = PropertyValuesHolder.ofKeyframe(androidProp, *kfs)
                    val animator = ObjectAnimator.ofPropertyValuesHolder(view, pvh)
                    animator.duration = duration
                    animators.add(animator)
                }
            }

            if (animators.isEmpty()) {
                callback(null, null)
                return@post
            }

            val set = AnimatorSet()
            set.playTogether(animators)
            set.addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(a: Animator) {
                    callback(null, null)
                }
            })
            set.start()
        }
    }

    // ── sequence(animations) ───────────────────────────────────────────────
    // args[0]: List<Map> animations [{ type, viewId, toStyles, options }, ...]

    private fun handleSequence(args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val animationsRaw = args.getOrNull(0) as? List<*> ?: run {
            callback(null, "sequence: invalid args")
            return
        }
        val animations = animationsRaw.mapNotNull { toStringKeyMap(it) }
        if (animations.isEmpty()) {
            callback(null, null)
            return
        }

        runSequenceStep(animations, 0, bridge, callback)
    }

    private fun runSequenceStep(
        animations: List<Map<String, Any?>>,
        index: Int,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit
    ) {
        if (index >= animations.size) {
            callback(null, null)
            return
        }

        val animData = animations[index]
        val method = animData["type"]?.toString() ?: "timing"
        val viewId = StyleEngine.toInt(animData["viewId"], 0)
        val toStyles = toStringKeyMap(animData["toStyles"]) ?: emptyMap()
        val options = toStringKeyMap(animData["options"]) ?: emptyMap()

        val subArgs: List<Any?> = listOf(viewId, toStyles, options)
        invoke(method, subArgs, bridge) { _, error ->
            if (error != null) {
                callback(null, error)
                return@invoke
            }
            runSequenceStep(animations, index + 1, bridge, callback)
        }
    }

    // ── parallel(animations) ───────────────────────────────────────────────
    // args[0]: List<Map> animations [{ type, viewId, toStyles, options }, ...]

    private fun handleParallel(args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val animationsRaw = args.getOrNull(0) as? List<*> ?: run {
            callback(null, "parallel: invalid args")
            return
        }
        val animations = animationsRaw.mapNotNull { toStringKeyMap(it) }
        if (animations.isEmpty()) {
            callback(null, null)
            return
        }

        val total = animations.size
        var completed = 0
        val lock = Object()

        for (animData in animations) {
            val method = animData["type"]?.toString() ?: "timing"
            val viewId = StyleEngine.toInt(animData["viewId"], 0)
            val toStyles = toStringKeyMap(animData["toStyles"]) ?: emptyMap()
            val options = toStringKeyMap(animData["options"]) ?: emptyMap()

            val subArgs: List<Any?> = listOf(viewId, toStyles, options)
            invoke(method, subArgs, bridge) { _, _ ->
                val allDone: Boolean
                synchronized(lock) {
                    completed++
                    allDone = completed == total
                }
                if (allDone) callback(null, null)
            }
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    /**
     * Build a list of ObjectAnimator from a toStyles map like { opacity: 1, translateX: 100 }.
     * Each style key maps to one or more Android View properties.
     */
    private fun buildPropertyAnimators(view: View, toStyles: Map<String, Any?>): List<Animator> {
        val animators = mutableListOf<Animator>()
        for ((key, value) in toStyles) {
            val toValue = StyleEngine.toFloat(value, Float.NaN)
            if (toValue.isNaN()) continue
            val androidProps = mapPropertyName(key)
            for (prop in androidProps) {
                animators.add(ObjectAnimator.ofFloat(view, prop, toValue))
            }
        }
        return animators
    }

    /**
     * Map a JS-side property name to Android View property name(s).
     * "scale" maps to both "scaleX" and "scaleY".
     */
    private fun mapPropertyName(propKey: String): List<String> = when (propKey) {
        "opacity" -> listOf("alpha")
        "translateX" -> listOf("translationX")
        "translateY" -> listOf("translationY")
        "scale" -> listOf("scaleX", "scaleY")
        "scaleX" -> listOf("scaleX")
        "scaleY" -> listOf("scaleY")
        "rotate" -> listOf("rotation")
        else -> emptyList()
    }

    /**
     * Resolve an easing string to an Android Interpolator.
     */
    private fun resolveInterpolator(easing: String) = when (easing) {
        "linear" -> LinearInterpolator()
        "ease-in", "easeIn" -> AccelerateInterpolator()
        "ease-out", "easeOut" -> DecelerateInterpolator()
        else -> AccelerateDecelerateInterpolator() // "easeInOut", "ease", default
    }

    /**
     * Safely cast Any? to Map<String, Any?>, handling Map<*, *> from J2V8/JSON deserialization.
     */
    private fun toStringKeyMap(value: Any?): Map<String, Any?>? {
        val map = value as? Map<*, *> ?: return null
        @Suppress("UNCHECKED_CAST")
        return map as Map<String, Any?>
    }
}
