import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueNative from '@thelacanians/vue-native-vite-plugin'

export default defineConfig({
  plugins: [
    vue(),
    vueNative({
      platform: 'ios',
      nativeCodegen: true,
      nativeOutputDirs: {
        ios: 'generated/ios',
        android: 'generated/android',
        typescript: 'app/generated',
      },
    }),
  ],
})
