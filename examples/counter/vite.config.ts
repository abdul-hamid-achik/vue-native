import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueNative from '@thelacanians/vite-plugin'

export default defineConfig({
  plugins: [
    // @vitejs/plugin-vue compiles .vue SFCs (templates, <script setup>, etc.)
    vue(),
    // @thelacanians/vite-plugin aliases 'vue' to '@thelacanians/runtime' and
    // configures IIFE build output for embedding in native iOS apps
    vueNative({
      platform: 'ios',
      globalName: 'CounterApp',
    }),
  ],
  build: {
    lib: {
      entry: 'app/main.ts',
      formats: ['iife'],
      name: 'CounterApp',
      fileName: () => 'vue-native-bundle.js',
    },
    outDir: 'dist',
  },
})
