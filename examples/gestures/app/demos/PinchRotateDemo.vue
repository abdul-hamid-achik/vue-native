<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { createStyleSheet, useGesture, VView, VText } from '@thelacanians/vue-native-runtime'
import { demoStyles } from '../styles'

const viewRef = ref()
const { pinch, rotate, isGesturing } = useGesture(viewRef, { pinch: true, rotate: true })

const baseScale = ref(1)
const baseRotation = ref(0)

const styles = createStyleSheet({
  box: {
    width: 150,
    height: 150,
    backgroundColor: '#007AFF',
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
  },
  boxActive: {
    backgroundColor: '#5856D6',
  },
})

const imageStyle = computed(() => [
  styles.box,
  isGesturing.value && styles.boxActive,
  {
    transform: [
      { scale: baseScale.value * (pinch.value?.scale ?? 1) },
      { rotate: `${baseRotation.value + (rotate.value?.rotation ?? 0)}rad` },
    ],
  },
])

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
</script>

<template>
  <VView ref="viewRef" :style="imageStyle">
    <VText :style="demoStyles.infoText">Pinch &amp; Rotate</VText>
  </VView>
  <VView :style="demoStyles.stateBox">
    <VText :style="demoStyles.stateLabel">Scale:</VText>
    <VText :style="demoStyles.stateValue">{{ (baseScale * (pinch?.scale ?? 1)).toFixed(2) }}</VText>
    <VText :style="demoStyles.stateLabel">Rotation:</VText>
    <VText :style="demoStyles.stateValue">{{ ((baseRotation + (rotate?.rotation ?? 0)) * 180 / 3.14159).toFixed(0) }}°</VText>
  </VView>
</template>
