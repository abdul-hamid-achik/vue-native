package com.vuenative.core

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View

class AnimationModule : NativeModule {
    override val moduleName = "Animation"
    private var context: Context? = null
    private var bridge: NativeBridge? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context; this.bridge = bridge
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        when (method) {
            "timing" -> {
                val nodeId   = StyleEngine.toInt(args.getOrNull(0), -1)
                val config   = args.getOrNull(1) as? Map<*, *> ?: emptyMap<String, Any>()
                val toValue  = StyleEngine.toFloat(config["toValue"], 0f)
                val property = config["property"]?.toString() ?: "opacity"
                val duration = StyleEngine.toInt(config["duration"], 300)
                val view     = bridge.nodeViews[nodeId] ?: run { callback(null, "View not found"); return }

                Handler(Looper.getMainLooper()).post {
                    animateTiming(view, property, toValue, duration.toLong()) {
                        callback(null, null)
                    }
                }
            }
            "spring" -> {
                val nodeId   = StyleEngine.toInt(args.getOrNull(0), -1)
                val config   = args.getOrNull(1) as? Map<*, *> ?: emptyMap<String, Any>()
                val toValue  = StyleEngine.toFloat(config["toValue"], 0f)
                val property = config["property"]?.toString() ?: "opacity"
                val view     = bridge.nodeViews[nodeId] ?: run { callback(null, "View not found"); return }

                Handler(Looper.getMainLooper()).post {
                    animateTiming(view, property, toValue, 400L) {
                        callback(null, null)
                    }
                }
            }
            "fadeIn" -> {
                val nodeId = StyleEngine.toInt(args.getOrNull(0), -1)
                val view = bridge.nodeViews[nodeId] ?: run { callback(null, null); return }
                Handler(Looper.getMainLooper()).post {
                    view.alpha = 0f; view.visibility = View.VISIBLE
                    view.animate().alpha(1f).setDuration(300).withEndAction { callback(null, null) }.start()
                }
            }
            "fadeOut" -> {
                val nodeId = StyleEngine.toInt(args.getOrNull(0), -1)
                val view = bridge.nodeViews[nodeId] ?: run { callback(null, null); return }
                Handler(Looper.getMainLooper()).post {
                    view.animate().alpha(0f).setDuration(300).withEndAction {
                        view.visibility = View.INVISIBLE
                        callback(null, null)
                    }.start()
                }
            }
            else -> callback(null, "Unknown animation method: $method")
        }
    }

    private fun animateTiming(view: View, property: String, toValue: Float, duration: Long, onEnd: () -> Unit) {
        val animator: Animator = when (property) {
            "opacity"    -> ObjectAnimator.ofFloat(view, "alpha", toValue)
            "translateX" -> ObjectAnimator.ofFloat(view, "translationX", toValue)
            "translateY" -> ObjectAnimator.ofFloat(view, "translationY", toValue)
            "scaleX"     -> ObjectAnimator.ofFloat(view, "scaleX", toValue)
            "scaleY"     -> ObjectAnimator.ofFloat(view, "scaleY", toValue)
            "scale"      -> AnimatorSet().apply {
                playTogether(
                    ObjectAnimator.ofFloat(view, "scaleX", toValue),
                    ObjectAnimator.ofFloat(view, "scaleY", toValue)
                )
            }
            "rotate"     -> ObjectAnimator.ofFloat(view, "rotation", toValue)
            else         -> ObjectAnimator.ofFloat(view, "alpha", toValue)
        }
        when (animator) {
            is ValueAnimator -> animator.duration = duration
            is AnimatorSet   -> animator.duration = duration
        }
        animator.addListener(object : AnimatorListenerAdapter() {
            override fun onAnimationEnd(a: Animator) { onEnd() }
        })
        animator.start()
    }
}
