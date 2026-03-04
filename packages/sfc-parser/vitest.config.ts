import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    name: '@thelacanians/vue-native-sfc-parser',
    environment: 'node',
    include: ['src/**/__tests__/*.test.ts'],
  },
})
