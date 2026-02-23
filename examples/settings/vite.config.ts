import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueNative from '@thelacanians/vue-native-vite-plugin'

export default defineConfig({
  plugins: [
    vue(),
    vueNative({
      platform: 'ios',
      globalName: 'SettingsApp',
    }),
  ],
  build: {
    lib: {
      entry: 'app/main.ts',
      formats: ['iife'],
      name: 'SettingsApp',
      fileName: () => 'vue-native-bundle.js',
    },
    outDir: 'dist',
  },
})
