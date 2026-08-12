import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'node',
    globals: true,
    include: ['src/**/*.test.ts', 'src/**/*.spec.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      include: ['src/**/*.ts'],
      exclude: ['src/**/*.test.ts', 'src/**/*.spec.ts', 'src/index.ts'],
      // Floors sit a couple of points under current coverage so CI fails on a
      // real regression without flaking on small refactors. Raise them as
      // coverage grows; never lower them to get a PR through.
      thresholds: {
        statements: 74,
        branches: 58,
        functions: 70,
        lines: 76,
      },
    },
  },
  resolve: {
    alias: {
      '@vue/runtime-core': '@vue/runtime-core',
    },
  },
})
