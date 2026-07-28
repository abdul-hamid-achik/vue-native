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
import org.json.JSONArray

class VViewFactory : NativeComponentFactory {
    override fun createView(context: Context): View {
        return VueNativeFlexboxLayout(context).apply {
            flexDirection = FlexDirection.COLUMN
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        if (key == "nativeDrivenGestures") {
            // Gesture names (e.g. ["pan"]) whose visual effect is applied by the
            // native gesture handler directly on the view's transform, instead of
            // waiting for a JS round-trip per frame. The matching JS event still
            // fires; this only changes who paints the intermediate frames.
            view.setTag(Tags.NATIVE_DRIVEN_GESTURES, parseGestureNames(value))
            return
        }
        StyleEngine.apply(key, value, view)
    }

    /** Normalize the `nativeDrivenGestures` prop (JSONArray or List) into a Set of names. */
    private fun parseGestureNames(value: Any?): Set<String> = when (value) {
        is JSONArray -> (0 until value.length()).mapNotNull { i -> value.opt(i)?.toString() }.toSet()
        is List<*> -> value.filterIsInstance<String>().toSet()
        else -> emptySet()
    }

    /** Whether the given gesture is marked native-driven on this view. */
    private fun isNativeDriven(view: View, gesture: String): Boolean {
        val gestures = view.getTag(Tags.NATIVE_DRIVEN_GESTURES) as? Set<*> ?: return false
        return gesture in gestures
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
                // Native-drive state. When "pan" is listed in the view's
                // `nativeDrivenGestures`, we apply the accumulated translation
                // straight to the view's transform on the UI thread (no JS
                // round-trip per frame). The `pan` event still fires to JS below.
                //
                // Interaction with style transforms: StyleEngine.applyTransform
                // and absolute positioning also write translationX/translationY.
                // To avoid clobbering them, we snapshot the view's translation at
                // the start of each gesture as a baseline and add the pan delta on
                // top of it. If a style transform changes *during* an active pan it
                // will be overwritten for the remainder of that gesture; this is an
                // accepted edge case (native-driven pans are meant for draggable
                // views without a competing animated transform).
                var baseTranslationX = 0f
                var baseTranslationY = 0f
                var accumulatedX = 0f
                var accumulatedY = 0f
                var gestureActive = false
                val gestureDetector = GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
                    override fun onScroll(e1: MotionEvent?, e2: MotionEvent, distanceX: Float, distanceY: Float): Boolean {
                        val translationX = -distanceX
                        val translationY = -distanceY
                        if (isNativeDriven(view, "pan")) {
                            if (!gestureActive) {
                                gestureActive = true
                                baseTranslationX = view.translationX
                                baseTranslationY = view.translationY
                                accumulatedX = 0f
                                accumulatedY = 0f
                            }
                            accumulatedX += translationX
                            accumulatedY += translationY
                            view.translationX = baseTranslationX + accumulatedX
                            view.translationY = baseTranslationY + accumulatedY
                        }
                        val payload = mapOf(
                            "translationX" to translationX,
                            "translationY" to translationY,
                            "velocityX" to 0f,
                            "velocityY" to 0f,
                            "state" to "changed"
                        )
                        handler(payload)
                        return true
                    }
                })
                view.setOnTouchListener { _, motionEvent ->
                    when (motionEvent.action) {
                        MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                            // End the gesture; the view keeps its last position.
                            // The next gesture re-snapshots the baseline so drags
                            // accumulate from the resting transform.
                            gestureActive = false
                        }
                    }
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
