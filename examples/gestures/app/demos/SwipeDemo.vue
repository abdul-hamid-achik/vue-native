<script setup lang="ts">
import { ref, watch } from 'vue'
import { createStyleSheet, useGesture, VView, VText } from '@thelacanians/vue-native-runtime'
import { demoStyles } from '../styles'

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

const styles = createStyleSheet({
  box: {
    width: 280,
    height: 200,
    backgroundColor: '#007AFF',
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
  },
})
</script>

<template>
  <VView ref="viewRef" :style="styles.box">
    <VText :style="{ color: '#FFFFFF', fontSize: 18, fontWeight: '600' }">{{ lastSwipe }}</VText>
  </VView>
  <VView :style="demoStyles.stateBox">
    <VText :style="demoStyles.stateLabel">Swipe Counts:</VText>
    <VText :style="demoStyles.stateValue">← Left: {{ swipeCount.left }}</VText>
    <VText :style="demoStyles.stateValue">→ Right: {{ swipeCount.right }}</VText>
    <VText :style="demoStyles.stateValue">↑ Up: {{ swipeCount.up }}</VText>
    <VText :style="demoStyles.stateValue">↓ Down: {{ swipeCount.down }}</VText>
  </VView>
</template>
