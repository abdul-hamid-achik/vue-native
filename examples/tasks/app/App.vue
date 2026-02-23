<script setup lang="ts">
import { createStyleSheet } from '@thelacanians/vue-native-runtime'
import { RouterView } from '@thelacanians/vue-native-navigation'

const styles = createStyleSheet({
  container: { flex: 1 },
})
</script>

<template>
  <VView :style="styles.container">
    <RouterView />
  </VView>
</template>
