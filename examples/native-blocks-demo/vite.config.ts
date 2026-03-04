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
        ios: '../../native/ios/VueNativeCore/Sources/VueNativeCore/GeneratedModules',
        android: '../../native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/GeneratedModules',
        typescript: 'app/generated',
      },
    }),
  ],
})
