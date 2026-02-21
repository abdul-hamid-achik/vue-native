import { ref, onMounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

export interface DeviceInfo {
  model: string
  systemVersion: string
  systemName: string
  name: string
  screenWidth: number
  screenHeight: number
  scale: number
}

/**
 * Device information composable.
 *
 * Fetches device info once on mount and exposes reactive refs.
 *
 * @example
 * ```ts
 * const { model, screenWidth, screenHeight } = useDeviceInfo()
 * ```
 */
export function useDeviceInfo() {
  const model = ref('')
  const systemVersion = ref('')
  const systemName = ref('')
  const name = ref('')
  const screenWidth = ref(0)
  const screenHeight = ref(0)
  const scale = ref(1)
  const isLoaded = ref(false)

  async function fetchInfo(): Promise<void> {
    const info = await NativeBridge.invokeNativeModule('DeviceInfo', 'getInfo', []) as DeviceInfo
    model.value = info.model ?? ''
    systemVersion.value = info.systemVersion ?? ''
    systemName.value = info.systemName ?? ''
    name.value = info.name ?? ''
    screenWidth.value = info.screenWidth ?? 0
    screenHeight.value = info.screenHeight ?? 0
    scale.value = info.scale ?? 1
    isLoaded.value = true
  }

  onMounted(() => {
    fetchInfo()
  })

  return {
    model,
    systemVersion,
    systemName,
    name,
    screenWidth,
    screenHeight,
    scale,
    isLoaded,
    fetchInfo,
  }
}
