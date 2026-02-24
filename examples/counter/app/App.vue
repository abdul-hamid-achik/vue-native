<script setup lang="ts">
import { ref, computed } from 'vue'
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const name = ref('World')
const count = ref(0)

const greeting = computed(() => `Hello, ${name.value}!`)

function increment() {
  count.value++
}

function decrement() {
  if (count.value > 0) {
    count.value--
  }
}

const styles = createStyleSheet({
  container: {
    flex: 1,
    padding: 24,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F5F5F5',
  },
  greeting: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1A1A2E',
    marginBottom: 16,
  },
  input: {
    width: 280,
    padding: 12,
    borderWidth: 1,
    borderColor: '#CCCCCC',
    borderRadius: 8,
    fontSize: 16,
    backgroundColor: '#FFFFFF',
    marginBottom: 32,
  },
  countText: {
    fontSize: 48,
    fontWeight: 'bold',
    color: '#16213E',
    marginBottom: 24,
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 16,
  },
  button: {
    paddingHorizontal: 32,
    paddingVertical: 14,
    borderRadius: 12,
    minWidth: 80,
    alignItems: 'center',
    justifyContent: 'center',
  },
  incrementButton: {
    backgroundColor: '#0F3460',
  },
  decrementButton: {
    backgroundColor: '#E94560',
  },
  buttonText: {
    color: '#FFFFFF',
    fontSize: 22,
    fontWeight: 'bold',
  },
})
</script>

<template>
  <VView :style="styles.container">
    <VText :style="styles.greeting">{{ greeting }}</VText>

    <VInput
      v-model="name"
      placeholder="Enter your name"
      :style="styles.input"
    />

    <VText :style="styles.countText">Count: {{ count }}</VText>

    <VView :style="styles.buttonRow">
      <VButton
        :style="[styles.button, styles.decrementButton]"
        :on-press="decrement"
      >
        <VText :style="styles.buttonText">-</VText>
      </VButton>

      <VButton
        :style="[styles.button, styles.incrementButton]"
        :on-press="increment"
      >
        <VText :style="styles.buttonText">+</VText>
      </VButton>
    </VView>
  </VView>
</template>
