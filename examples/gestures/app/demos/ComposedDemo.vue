<script setup lang="ts">
import { ref } from 'vue'
import { createStyleSheet, useComposedGestures, VView, VText } from '@thelacanians/vue-native-runtime'
import { demoStyles } from '../styles'

const viewRef = ref()
const { isGesturing, isPinchingAndRotating, isPanningAndPinching } = useComposedGestures(viewRef)

const styles = createStyleSheet({
  box: {
    width: 200,
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
    fontSize: 14,
    fontWeight: '600',
    textAlign: 'center',
  },
})
</script>

<template>
  <VView ref="viewRef" :style="[styles.box, isGesturing && styles.boxActive]">
    <VText :style="styles.hint">
      Use 2 fingers to pinch &amp; rotate
      Use 1 finger to pan
    </VText>
  </VView>
  <VView :style="demoStyles.stateBox">
    <VText :style="demoStyles.stateLabel">isPinchingAndRotating:</VText>
    <VText :style="demoStyles.stateValue">{{ isPinchingAndRotating ? 'Yes!' : 'No' }}</VText>
    <VText :style="demoStyles.stateLabel">isPanningAndPinching:</VText>
    <VText :style="demoStyles.stateValue">{{ isPanningAndPinching ? 'Yes!' : 'No' }}</VText>
    <VText :style="demoStyles.stateLabel">Active Gesture:</VText>
    <VText :style="demoStyles.stateValue">{{ isGesturing ? 'Yes' : 'No' }}</VText>
  </VView>
</template>
