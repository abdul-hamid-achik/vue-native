import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueNative from '@thelacanians/vue-native-vite-plugin'

export default defineConfig({
  plugins: [
    vue(),
    vueNative({
      platform: 'ios',
      globalName: 'AuthFlowApp',
    }),
  ],
  build: {
    lib: {
      entry: 'app/main.ts',
      formats: ['iife'],
      name: 'AuthFlowApp',
      fileName: () => 'vue-native-bundle.js',
    },
    outDir: 'dist',
  },
})
