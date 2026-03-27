<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import {
  createStyleSheet,
  useGesture,
  useComposedGestures,
  VView,
  VText,
  VPressable,
} from '@thelacanians/vue-native-runtime'

type Tab = 'pan' | 'pinch' | 'swipe' | 'composed' | 'all'

const activeTab = ref<Tab>('pan')

const styles = createStyleSheet({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
  tabBar: {
    flexDirection: 'row',
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  tab: {
    flex: 1,
    paddingVertical: 16,
    alignItems: 'center',
  },
  tabActive: {
    borderBottomWidth: 2,
    borderBottomColor: '#007AFF',
  },
  tabText: {
    fontSize: 14,
    color: '#666666',
  },
  tabTextActive: {
    color: '#007AFF',
    fontWeight: '600',
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  infoText: {
    fontSize: 16,
    color: '#FFFFFF',
    fontWeight: '600',
  },
  stateBox: {
    padding: 16,
    backgroundColor: '#FFFFFF',
    borderRadius: 8,
    marginTop: 20,
    minWidth: 280,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  stateLabel: {
    fontSize: 12,
    color: '#999999',
    marginBottom: 2,
  },
  stateValue: {
    fontSize: 14,
    color: '#333333',
    marginBottom: 8,
  },
})

// ============ Pan Demo ============
const PanDemo = {
  setup() {
    const viewRef = ref()
    const { pan, isGesturing } = useGesture(viewRef, { pan: true })

    const offsetX = ref(0)
    const offsetY = ref(0)

    watch(() => pan.value?.state, (state) => {
      if (state === 'ended' && pan.value) {
        offsetX.value += pan.value.translationX
        offsetY.value += pan.value.translationY
      }
    })

    const boxStyle = computed(() => ({
      width: 100,
      height: 100,
      backgroundColor: isGesturing.value ? '#5856D6' : '#007AFF',
      borderRadius: 8,
      justifyContent: 'center',
      alignItems: 'center',
      transform: [
        { translateX: offsetX.value + (pan.value?.translationX ?? 0) },
        { translateY: offsetY.value + (pan.value?.translationY ?? 0) },
      ],
    }))

    return { viewRef, pan, isGesturing, offsetX, offsetY, boxStyle, styles }
  },
  template: `
    <VView ref="viewRef" :style="boxStyle">
      <VText :style="styles.infoText">{{ isGesturing ? 'Dragging...' : 'Drag Me' }}</VText>
    </VView>
    <VView :style="styles.stateBox">
      <VText :style="styles.stateLabel">Translation X:</VText>
      <VText :style="styles.stateValue">{{ (pan?.translationX ?? 0).toFixed(1) }}</VText>
      <VText :style="styles.stateLabel">Translation Y:</VText>
      <VText :style="styles.stateValue">{{ (pan?.translationY ?? 0).toFixed(1) }}</VText>
      <VText :style="styles.stateLabel">State:</VText>
      <VText :style="styles.stateValue">{{ pan?.state ?? 'idle' }}</VText>
    </VView>
  `,
}

// ============ Pinch/Rotate Demo ============
const PinchRotateDemo = {
  setup() {
    const viewRef = ref()
    const { pinch, rotate, isGesturing } = useGesture(viewRef, { pinch: true, rotate: true })

    const baseScale = ref(1)
    const baseRotation = ref(0)

    const imageStyle = computed(() => ({
      width: 150,
      height: 150,
      backgroundColor: isGesturing.value ? '#5856D6' : '#007AFF',
      borderRadius: 8,
      justifyContent: 'center',
      alignItems: 'center',
      transform: [
        { scale: baseScale.value * (pinch.value?.scale ?? 1) },
        { rotate: `${baseRotation.value + (rotate.value?.rotation ?? 0)}rad` },
      ],
    }))

    watch(() => pinch.value?.state, (state) => {
      if (state === 'ended' && pinch.value) {
        baseScale.value *= pinch.value.scale
      }
    })

    watch(() => rotate.value?.state, (state) => {
      if (state === 'ended' && rotate.value) {
        baseRotation.value += rotate.value.rotation
      }
    })

    return { viewRef, pinch, rotate, isGesturing, baseScale, baseRotation, imageStyle, styles }
  },
  template: `
    <VView ref="viewRef" :style="imageStyle">
      <VText :style="{ color: '#FFFFFF', fontWeight: '600' }">Pinch &amp; Rotate</VText>
    </VView>
    <VView :style="{ ...styles.stateBox, marginTop: 20 }">
      <VText :style="styles.stateLabel">Scale:</VText>
      <VText :style="styles.stateValue">{{ (baseScale * (pinch?.scale ?? 1)).toFixed(2) }}</VText>
      <VText :style="styles.stateLabel">Rotation:</VText>
      <VText :style="styles.stateValue">{{ ((baseRotation + (rotate?.rotation ?? 0)) * 180 / 3.14159).toFixed(0) }}°</VText>
    </VView>
  `,
}

// ============ Swipe Demo ============
const SwipeDemo = {
  setup() {
    const viewRef = ref()
    const { swipeLeft, swipeRight, swipeUp, swipeDown } = useGesture(viewRef, {
      swipeLeft: true,
      swipeRight: true,
      swipeUp: true,
      swipeDown: true,
    })

    const lastSwipe = ref('Swipe in any direction')
    const swipeCount = ref({ left: 0, right: 0, up: 0, down: 0 })

    watch(swipeLeft, (state) => {
      if (state) {
        lastSwipe.value = 'Swiped Left!'
        swipeCount.value.left++
      }
    })
    watch(swipeRight, (state) => {
      if (state) {
        lastSwipe.value = 'Swiped Right!'
        swipeCount.value.right++
      }
    })
    watch(swipeUp, (state) => {
      if (state) {
        lastSwipe.value = 'Swiped Up!'
        swipeCount.value.up++
      }
    })
    watch(swipeDown, (state) => {
      if (state) {
        lastSwipe.value = 'Swiped Down!'
        swipeCount.value.down++
      }
    })

    return { viewRef, lastSwipe, swipeCount, styles }
  },
  template: `
    <VView ref="viewRef" :style="{ width: 280, height: 200, backgroundColor: '#007AFF', borderRadius: 12, justifyContent: 'center', alignItems: 'center' }">
      <VText :style="{ color: '#FFFFFF', fontSize: 18, fontWeight: '600' }">{{ lastSwipe }}</VText>
    </VView>
    <VView :style="{ ...styles.stateBox, marginTop: 20 }">
      <VText :style="styles.stateLabel">Swipe Counts:</VText>
      <VText :style="styles.stateValue">← Left: {{ swipeCount.left }}</VText>
      <VText :style="styles.stateValue">→ Right: {{ swipeCount.right }}</VText>
      <VText :style="styles.stateValue">↑ Up: {{ swipeCount.up }}</VText>
      <VText :style="styles.stateValue">↓ Down: {{ swipeCount.down }}</VText>
    </VView>
  `,
}

// ============ Composed Gestures Demo ============
const ComposedDemo = {
  setup() {
    const viewRef = ref()
    const { pan, pinch, rotate, isGesturing, isPinchingAndRotating, isPanningAndPinching } = useComposedGestures(viewRef)

    return { viewRef, pan, pinch, rotate, isGesturing, isPinchingAndRotating, isPanningAndPinching, styles }
  },
  template: `
    <VView ref="viewRef" :style="{ width: 200, height: 200, backgroundColor: isGesturing ? '#5856D6' : '#007AFF', borderRadius: 12, justifyContent: 'center', alignItems: 'center', padding: 16 }">
      <VText :style="{ color: '#FFFFFF', fontSize: 14, fontWeight: '600', textAlign: 'center' }">
        Use 2 fingers to pinch &amp; rotate
        Use 1 finger to pan
      </VText>
    </VView>
    <VView :style="{ ...styles.stateBox, marginTop: 20 }">
      <VText :style="styles.stateLabel">isPinchingAndRotating:</VText>
      <VText :style="styles.stateValue">{{ isPinchingAndRotating ? 'Yes!' : 'No' }}</VText>
      <VText :style="styles.stateLabel">isPanningAndPinching:</VText>
      <VText :style="styles.stateValue">{{ isPanningAndPinching ? 'Yes!' : 'No' }}</VText>
      <VText :style="styles.stateLabel">Active Gesture:</VText>
      <VText :style="styles.stateValue">{{ isGesturing ? 'Yes' : 'No' }}</VText>
    </VView>
  `,
}

// ============ All Gestures Demo ============
const AllGesturesDemo = {
  setup() {
    const viewRef = ref()
    const { pan, pinch, press, doubleTap, isGesturing } = useGesture(viewRef, {
      pan: true,
      pinch: true,
      press: true,
      doubleTap: true,
    })

    const lastGesture = ref('Tap or gesture me!')

    watch(press, (state) => {
      if (state) lastGesture.value = 'Pressed!'
    })
    watch(doubleTap, (state) => {
      if (state) lastGesture.value = 'Double tapped!'
    })
    watch(pan, (state) => {
      if (state) lastGesture.value = `Panning: ${state.translationX.toFixed(0)}, ${state.translationY.toFixed(0)}`
    })
    watch(pinch, (state) => {
      if (state) lastGesture.value = `Pinch scale: ${state.scale.toFixed(2)}`
    })

    return { viewRef, pan, pinch, press, doubleTap, isGesturing, lastGesture, styles }
  },
  template: `
    <VView ref="viewRef" :style="{ width: 280, height: 200, backgroundColor: isGesturing ? '#5856D6' : '#007AFF', borderRadius: 12, justifyContent: 'center', alignItems: 'center', padding: 16 }">
      <VText :style="{ color: '#FFFFFF', fontSize: 16, fontWeight: '600', textAlign: 'center' }">{{ lastGesture }}</VText>
    </VView>
    <VText :style="{ marginTop: 20, color: '#666666', fontSize: 14, textAlign: 'center' }">Try: Pan, Pinch, Press, Double-tap</VText>
  `,
}
</script>

<template>
  <VView :style="styles.container">
    <!-- Tab Bar -->
    <VView :style="styles.tabBar">
      <VPressable
        v-for="tab in (['pan', 'pinch', 'swipe', 'composed', 'all'] as Tab[])"
        :key="tab"
        :style="[styles.tab, activeTab === tab && styles.tabActive]"
        :on-press="() => activeTab = tab"
      >
        <VText :style="[styles.tabText, activeTab === tab && styles.tabTextActive]">
          {{ tab.charAt(0).toUpperCase() + tab.slice(1) }}
        </VText>
      </VPressable>
    </VView>

    <!-- Pan Gesture Demo -->
    <VView v-if="activeTab === 'pan'" :style="styles.content">
      <PanDemo />
    </VView>

    <!-- Pinch/Rotate Demo -->
    <VView v-else-if="activeTab === 'pinch'" :style="styles.content">
      <PinchRotateDemo />
    </VView>

    <!-- Swipe Demo -->
    <VView v-else-if="activeTab === 'swipe'" :style="styles.content">
      <SwipeDemo />
    </VView>

    <!-- Composed Gestures Demo -->
    <VView v-else-if="activeTab === 'composed'" :style="styles.content">
      <ComposedDemo />
    </VView>

    <!-- All Gestures Demo -->
    <VView v-else-if="activeTab === 'all'" :style="styles.content">
      <AllGesturesDemo />
    </VView>
  </VView>
</template>
