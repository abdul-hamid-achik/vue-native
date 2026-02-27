<script setup lang="ts">
import { computed } from 'vue'
import { createStyleSheet } from '@thelacanians/vue-native-runtime'
import { useRouter, useRoute } from '@thelacanians/vue-native-navigation'

const router = useRouter()
const route = useRoute()

const params = computed(() => route.value.params ?? {})

const styles = createStyleSheet({
  container: {
    flex: 1,
    padding: 24,
    backgroundColor: '#F2F2F7',
    justifyContent: 'center',
    alignItems: 'center',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1C1C1E',
    marginBottom: 8,
  },
  info: {
    fontSize: 16,
    color: '#8E8E93',
    marginBottom: 32,
  },
  backButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 10,
  },
  backText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
})
</script>

<template>
  <VView :style="styles.container">
    <VText :style="styles.title">{{ params.title ?? 'Detail' }}</VText>
    <VText :style="styles.info">ID: {{ params.id ?? 'unknown' }}</VText>
    <VButton :style="styles.backButton" :on-press="() => router.pop()">
      <VText :style="styles.backText">Go Back</VText>
    </VButton>
  </VView>
</template>
