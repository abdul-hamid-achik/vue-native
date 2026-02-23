import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueNative from '@thelacanians/vue-native-vite-plugin'

export default defineConfig({
  plugins: [
    vue(),
    vueNative({
      platform: 'ios',
      globalName: 'SocialApp',
    }),
  ],
  build: {
    lib: {
      entry: 'app/main.ts',
      formats: ['iife'],
      name: 'SocialApp',
      fileName: () => 'vue-native-bundle.js',
    },
    outDir: 'dist',
  },
})
