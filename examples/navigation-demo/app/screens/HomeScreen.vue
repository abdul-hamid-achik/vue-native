<script setup lang="ts">
import { createStyleSheet } from '@thelacanians/vue-native-runtime'
import {
  useRouter,
  onScreenFocus,
  onScreenBlur,
} from '@thelacanians/vue-native-navigation'

const router = useRouter()

onScreenFocus(() => {
  console.log('[HomeScreen] focused')
})

onScreenBlur(() => {
  console.log('[HomeScreen] blurred')
})

function goToDetail(id: number) {
  router.push('Detail', { id: String(id), title: `Item ${id}` })
}

const items = [
  { id: 1, label: 'Getting Started', description: 'Introduction and setup guide' },
  { id: 2, label: 'Components', description: 'View the component gallery' },
  { id: 3, label: 'Navigation', description: 'Stack, tabs, and drawer demos' },
  { id: 4, label: 'Composables', description: 'Native module wrappers' },
]

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
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 15,
    color: '#8E8E93',
    marginBottom: 24,
  },
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
  },
  cardTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: '#1C1C1E',
    marginBottom: 4,
  },
  cardDescription: {
    fontSize: 14,
    color: '#8E8E93',
  },
})
</script>

<template>
  <VScrollView :style="styles.container">
    <VText :style="styles.title">Home</VText>
    <VText :style="styles.subtitle">Tap an item to navigate</VText>

    <VButton
      v-for="item in items"
      :key="item.id"
      :style="styles.card"
      :on-press="() => goToDetail(item.id)"
    >
      <VText :style="styles.cardTitle">{{ item.label }}</VText>
      <VText :style="styles.cardDescription">{{ item.description }}</VText>
    </VButton>
  </VScrollView>
</template>
