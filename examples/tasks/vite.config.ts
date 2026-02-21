import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueNative from '@vue-native/vite-plugin'

export default defineConfig({
  plugins: [
    vue(),
    vueNative({
      platform: 'ios',
      globalName: 'TasksApp',
    }),
  ],
  build: {
    lib: {
      entry: 'app/main.ts',
      formats: ['iife'],
      name: 'TasksApp',
      fileName: () => 'vue-native-bundle.js',
    },
    outDir: 'dist',
  },
})
