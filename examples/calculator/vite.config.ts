import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueNative from '@vue-native/vite-plugin'

export default defineConfig({
  plugins: [
    vue(),
    vueNative({
      platform: 'ios',
      globalName: 'CalculatorApp',
    }),
  ],
  build: {
    lib: {
      entry: 'app/main.ts',
      formats: ['iife'],
      name: 'CalculatorApp',
      fileName: () => 'vue-native-bundle.js',
    },
    outDir: 'dist',
  },
})
