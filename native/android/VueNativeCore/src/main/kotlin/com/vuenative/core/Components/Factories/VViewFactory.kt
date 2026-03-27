package com.vuenative.core

import android.content.Context
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View
import android.view.ViewGroup
import com.google.android.flexbox.FlexDirection
import com.google.android.flexbox.FlexboxLayout
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.sqrt

class VViewFactory : NativeComponentFactory {
    override fun createView(context: Context): View {
        return FlexboxLayout(context).apply {
            flexDirection = FlexDirection.COLUMN
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        StyleEngine.apply(key, value, view)
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        when (event) {
            "press" -> view.setOnClickListener { handler(null) }
            "longPress" -> view.setOnLongClickListener {
                handler(null)
                true
            }
            "pan", "swipeLeft", "swipeRight", "swipeUp", "swipeDown", "pinch", "rotate" -> {
                setupGestureListener(view, event, handler)
            }
        }
    }

    private fun setupGestureListener(view: View, event: String, handler: (Any?) -> Unit) {
        val context = view.context

        when (event) {
            "pan" -> {
                val gestureDetector = GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
                    override fun onScroll(e1: MotionEvent?, e2: MotionEvent, distanceX: Float, distanceY: Float): Boolean {
                        val payload = mapOf(
                            "translationX" to -distanceX,
                            "translationY" to -distanceY,
                            "velocityX" to 0f,
                            "velocityY" to 0f,
                            "state" to "changed"
                        )
                        handler(payload)
                        return true
                    }
                })
                view.setOnTouchListener { _, motionEvent ->
                    gestureDetector.onTouchEvent(motionEvent)
                    false
                }
            }
            "swipeLeft" -> {
                val gestureDetector = GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
                    override fun onFling(e1: MotionEvent?, e2: MotionEvent, velocityX: Float, velocityY: Float): Boolean {
                        if (abs(velocityX) > abs(velocityY) && velocityX < 0) {
                            val payload = mapOf("direction" to "left")
                            handler(payload)
                        }
                        return true
                    }
                })
                view.setOnTouchListener { _, motionEvent ->
                    gestureDetector.onTouchEvent(motionEvent)
                    false
                }
            }
            "swipeRight" -> {
                val gestureDetector = GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
                    override fun onFling(e1: MotionEvent?, e2: MotionEvent, velocityX: Float, velocityY: Float): Boolean {
                        if (abs(velocityX) > abs(velocityY) && velocityX > 0) {
                            val payload = mapOf("direction" to "right")
                            handler(payload)
                        }
                        return true
                    }
                })
                view.setOnTouchListener { _, motionEvent ->
                    gestureDetector.onTouchEvent(motionEvent)
                    false
                }
            }
            "swipeUp" -> {
                val gestureDetector = GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
                    override fun onFling(e1: MotionEvent?, e2: MotionEvent, velocityX: Float, velocityY: Float): Boolean {
                        if (abs(velocityY) > abs(velocityX) && velocityY < 0) {
                            val payload = mapOf("direction" to "up")
                            handler(payload)
                        }
                        return true
                    }
                })
                view.setOnTouchListener { _, motionEvent ->
                    gestureDetector.onTouchEvent(motionEvent)
                    false
                }
            }
            "swipeDown" -> {
                val gestureDetector = GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
                    override fun onFling(e1: MotionEvent?, e2: MotionEvent, velocityX: Float, velocityY: Float): Boolean {
                        if (abs(velocityY) > abs(velocityX) && velocityY > 0) {
                            val payload = mapOf("direction" to "down")
                            handler(payload)
                        }
                        return true
                    }
                })
                view.setOnTouchListener { _, motionEvent ->
                    gestureDetector.onTouchEvent(motionEvent)
                    false
                }
            }
            "pinch" -> {
                val scaleGestureDetector = ScaleGestureDetector(context, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
                    override fun onScale(detector: ScaleGestureDetector): Boolean {
                        val payload = mapOf(
                            "scale" to detector.scaleFactor,
                            "velocity" to detector.currentSpan,
                            "state" to "changed"
                        )
                        handler(payload)
                        return true
                    }
                })
                view.setOnTouchListener { _, motionEvent ->
                    scaleGestureDetector.onTouchEvent(motionEvent)
                    false
                }
            }
            "rotate" -> {
                val rotationDetector = RotationGestureDetector { rotation ->
                    val payload = mapOf(
                        "rotation" to rotation,
                        "state" to "changed"
                    )
                    handler(payload)
                }
                view.setOnTouchListener { _, motionEvent ->
                    rotationDetector.onTouchEvent(motionEvent)
                    false
                }
            }
        }
    }

    override fun removeEventListener(view: View, event: String) {
        when (event) {
            "press" -> view.setOnClickListener(null)
            "longPress" -> view.setOnLongClickListener(null)
            else -> view.setOnTouchListener(null)
        }
    }

    override fun insertChild(parent: View, child: View, index: Int) {
        val flex = parent as? FlexboxLayout ?: return
        val lp = StyleEngine.buildFlexLayoutParams(child)
        if (index >= flex.childCount) {
            flex.addView(child, lp)
        } else {
            flex.addView(child, index, lp)
        }
    }

    override fun removeChild(parent: View, child: View) {
        (parent as? ViewGroup)?.removeView(child)
    }

    /**
     * RotationGestureDetector detectsstwo-finger rotation gestures.
     * Calculates rotation angle between two touch points.
     */
    private class RotationGestureDetector(
        private val onRotation: (Float) -> Unit
    ) {
        private var previousAngle: Float = 0f
        private var isTracking = false

        fun onTouchEvent(event: MotionEvent): Boolean {
            when (event.actionMasked) {
                MotionEvent.ACTION_POINTER_DOWN -> {
                    if (event.pointerCount == 2) {
                        previousAngle = calculateAngle(event)
                        isTracking = true
                    }
                }
                MotionEvent.ACTION_MOVE -> {
                    if (isTracking && event.pointerCount == 2) {
                        val currentAngle = calculateAngle(event)
                        val deltaAngle = currentAngle - previousAngle
                        
                        // Normalize angle to -PI to PI range
                        val normalizedDelta = when {
                            deltaAngle > Math.PI -> deltaAngle - (2 * Math.PI).toFloat()
                            deltaAngle < -Math.PI -> deltaAngle + (2 * Math.PI).toFloat()
                            else -> deltaAngle
                        }
                        
                        onRotation(normalizedDelta)
                        previousAngle = currentAngle
                    }
                }
                MotionEvent.ACTION_POINTER_UP, MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    isTracking = false
                }
            }
            return true
        }

        private fun calculateAngle(event: MotionEvent): Float {
            if (event.pointerCount < 2) return 0f
            
            val dx = event.getX(1) - event.getX(0)
            val dy = event.getY(1) - event.getY(0)
            
            return atan2(dy, dx)
        }
    }
}