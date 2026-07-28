import { ref, onMounted, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

interface BatteryInfo {
  /** Battery level 0..1, or null when unavailable (e.g. desktop Mac). */
  level: number | null
  /** Whether the battery is charging, or null when unavailable. */
  isCharging: boolean | null
}

/**
 * Battery state composable.
 *
 * Reports the device battery level (0..1) and charging state. On platforms
 * without a battery (desktop Mac) `level`/`isCharging` stay `null` and
 * `isSupported` is `false`.
 *
 * @param options.pollInterval - refresh interval in ms (default 60s; 0 disables polling).
 *
 * @example
 * ```ts
 * const { level, isCharging, isSupported } = useBattery()
 * // level.value -> 0.83, isCharging.value -> true
 * ```
 */
export function useBattery(options: { pollInterval?: number } = {}) {
  const level = ref<number | null>(null)
  const isCharging = ref<boolean | null>(null)
  const isSupported = ref<boolean | null>(null)
  let timer: ReturnType<typeof setInterval> | null = null

  async function refresh(): Promise<void> {
    try {
      const info = await NativeBridge.invokeNativeModule<BatteryInfo>('Battery', 'getBatteryInfo', [])
      level.value = info?.level ?? null
      isCharging.value = info?.isCharging ?? null
      isSupported.value = info?.level != null
    } catch {
      isSupported.value = false
    }
  }

  onMounted(() => {
    void refresh()
    const interval = options.pollInterval ?? 60_000
    if (interval > 0) {
      timer = setInterval(() => void refresh(), interval)
    }
  })

  onUnmounted(() => {
    if (timer !== null) {
      clearInterval(timer)
      timer = null
    }
  })

  return { level, isCharging, isSupported, refresh }
}
