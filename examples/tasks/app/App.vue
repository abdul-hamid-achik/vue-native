<script setup lang="ts">
import { createStyleSheet } from '@thelacanians/runtime'
import { RouterView } from '@thelacanians/navigation'

const styles = createStyleSheet({
  container: { flex: 1 },
})
</script>

<template>
  <VView :style="styles.container">
    <RouterView />
  </VView>
</template>
