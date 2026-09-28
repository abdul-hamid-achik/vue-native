<script setup lang="ts">
import { ref, watch } from 'vue'
import { createStyleSheet, useGesture, VView, VText } from '@thelacanians/vue-native-runtime'

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

const styles = createStyleSheet({
  box: {
    width: 280,
    height: 200,
    backgroundColor: '#007AFF',
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 16,
  },
  boxActive: {
    backgroundColor: '#5856D6',
  },
  hint: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
    textAlign: 'center',
  },
  footnote: {
    marginTop: 20,
    color: '#666666',
    fontSize: 14,
    textAlign: 'center',
  },
})
</script>

<template>
  <VView ref="viewRef" :style="[styles.box, isGesturing && styles.boxActive]">
    <VText :style="styles.hint">{{ lastGesture }}</VText>
  </VView>
  <VText :style="styles.footnote">Try: Pan, Pinch, Press, Double-tap</VText>
</template>
