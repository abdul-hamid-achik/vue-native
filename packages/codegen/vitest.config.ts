import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    name: '@thelacanians/vue-native-codegen',
    environment: 'node',
    include: ['src/**/__tests__/*.test.ts'],
  },
})
