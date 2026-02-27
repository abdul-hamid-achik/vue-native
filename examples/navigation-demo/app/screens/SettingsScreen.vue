<script setup lang="ts">
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  container: {
    flex: 1,
    padding: 20,
    backgroundColor: '#F2F2F7',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1C1C1E',
    marginBottom: 16,
  },
  row: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    marginBottom: 8,
  },
  rowText: {
    fontSize: 16,
    color: '#1C1C1E',
  },
})
</script>

<template>
  <VView :style="styles.container">
    <VText :style="styles.title">Settings</VText>
    <VView :style="styles.row">
      <VText :style="styles.rowText">Account</VText>
    </VView>
    <VView :style="styles.row">
      <VText :style="styles.rowText">Notifications</VText>
    </VView>
    <VView :style="styles.row">
      <VText :style="styles.rowText">Privacy</VText>
    </VView>
    <VView :style="styles.row">
      <VText :style="styles.rowText">About</VText>
    </VView>
  </VView>
</template>
