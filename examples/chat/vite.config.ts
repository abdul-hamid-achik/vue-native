import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueNative from '@thelacanians/vue-native-vite-plugin'

export default defineConfig({
  plugins: [
    vue(),
    vueNative({
      platform: 'ios',
      globalName: 'ChatApp',
    }),
  ],
  build: {
    lib: {
      entry: 'app/main.ts',
      formats: ['iife'],
      name: 'ChatApp',
      fileName: () => 'vue-native-bundle.js',
    },
    outDir: 'dist',
  },
})
