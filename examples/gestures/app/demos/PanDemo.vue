<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { createStyleSheet, useGesture, VView, VText } from '@thelacanians/vue-native-runtime'
import { demoStyles } from '../styles'

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

const styles = createStyleSheet({
  box: {
    width: 100,
    height: 100,
    backgroundColor: '#007AFF',
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
  },
  boxActive: {
    backgroundColor: '#5856D6',
  },
})

const boxStyle = computed(() => [
  styles.box,
  isGesturing.value && styles.boxActive,
  {
    transform: [
      { translateX: offsetX.value + (pan.value?.translationX ?? 0) },
      { translateY: offsetY.value + (pan.value?.translationY ?? 0) },
    ],
  },
])
</script>

<template>
  <VView ref="viewRef" :style="boxStyle">
    <VText :style="demoStyles.infoText">{{ isGesturing ? 'Dragging...' : 'Drag Me' }}</VText>
  </VView>
  <VView :style="demoStyles.stateBox">
    <VText :style="demoStyles.stateLabel">Translation X:</VText>
    <VText :style="demoStyles.stateValue">{{ (pan?.translationX ?? 0).toFixed(1) }}</VText>
    <VText :style="demoStyles.stateLabel">Translation Y:</VText>
    <VText :style="demoStyles.stateValue">{{ (pan?.translationY ?? 0).toFixed(1) }}</VText>
    <VText :style="demoStyles.stateLabel">State:</VText>
    <VText :style="demoStyles.stateValue">{{ pan?.state ?? 'idle' }}</VText>
  </VView>
</template>
