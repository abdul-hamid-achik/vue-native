import { ref, onMounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

export function useI18n() {
  const isRTL = ref(false)
  const locale = ref('en')

  onMounted(async () => {
    try {
      const info = await NativeBridge.invokeNativeModule('DeviceInfo', 'getDeviceInfo', [])
      locale.value = info?.locale || 'en'
      isRTL.value = ['ar', 'he', 'fa', 'ur'].some(l => locale.value.startsWith(l))
    } catch {
      // DeviceInfo not available, defaults are fine
    }
  })

  return { isRTL, locale }
}
