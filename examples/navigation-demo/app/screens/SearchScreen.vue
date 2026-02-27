<script setup lang="ts">
import { ref } from 'vue'
import { createStyleSheet } from '@thelacanians/vue-native-runtime'
import { onScreenFocus } from '@thelacanians/vue-native-navigation'

const query = ref('')
const focusCount = ref(0)

onScreenFocus(() => {
  focusCount.value++
})

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
  input: {
    borderWidth: 1,
    borderColor: '#D1D1D6',
    borderRadius: 10,
    padding: 12,
    fontSize: 16,
    backgroundColor: '#FFFFFF',
    marginBottom: 16,
  },
  info: {
    fontSize: 14,
    color: '#8E8E93',
  },
})
</script>

<template>
  <VView :style="styles.container">
    <VText :style="styles.title">Search</VText>
    <VInput
      v-model="query"
      placeholder="Search..."
      :style="styles.input"
    />
    <VText :style="styles.info">
      Tab focused {{ focusCount }} time(s)
    </VText>
  </VView>
</template>
