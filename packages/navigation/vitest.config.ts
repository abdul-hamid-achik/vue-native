import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'node',
    globals: true,
    include: ['src/**/*.test.ts', 'src/**/*.spec.ts'],
  },
  resolve: {
    alias: {
      '@vue/runtime-core': '@vue/runtime-core',
      '@thelacanians/vue-native-runtime': '@thelacanians/vue-native-runtime',
    },
  },
})
