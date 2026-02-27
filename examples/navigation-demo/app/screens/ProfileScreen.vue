<script setup lang="ts">
import { createStyleSheet } from '@thelacanians/vue-native-runtime'
import { useDrawer } from '@thelacanians/vue-native-navigation'

const drawer = useDrawer()

const styles = createStyleSheet({
  container: {
    flex: 1,
    padding: 20,
    backgroundColor: '#F2F2F7',
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatar: {
    fontSize: 64,
    marginBottom: 16,
  },
  name: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1C1C1E',
    marginBottom: 4,
  },
  email: {
    fontSize: 15,
    color: '#8E8E93',
    marginBottom: 24,
  },
  menuButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 10,
  },
  menuText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
})
</script>

<template>
  <VView :style="styles.container">
    <VText :style="styles.avatar">👤</VText>
    <VText :style="styles.name">Jane Doe</VText>
    <VText :style="styles.email">jane@example.com</VText>

    <VButton :style="styles.menuButton" :on-press="() => drawer.toggleDrawer()">
      <VText :style="styles.menuText">Toggle Drawer</VText>
    </VButton>
  </VView>
</template>
