import { ref, onMounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

interface LocaleDeviceInfo {
  locale?: unknown
}

function normalizeLocale(value: unknown): string {
  if (typeof value !== 'string' || value.trim().length === 0) return 'en'
  return value.trim()
}

export function useI18n() {
  const isRTL = ref(false)
  const locale = ref('en')

  onMounted(async () => {
    try {
      // `getInfo` is the public DeviceInfo method on iOS, Android, and macOS.
      // Earlier Android builds accepted `getDeviceInfo`, but Apple never did.
      const info = await NativeBridge.invokeNativeModule('DeviceInfo', 'getInfo', []) as LocaleDeviceInfo | undefined
      locale.value = normalizeLocale(info?.locale)
      isRTL.value = ['ar', 'he', 'fa', 'ur'].some(l => locale.value.startsWith(l))
    } catch {
      // DeviceInfo not available, defaults are fine
    }
  })

  return { isRTL, locale }
}
