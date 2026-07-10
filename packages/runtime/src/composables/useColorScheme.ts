import { ref, onMounted, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

export type ColorScheme = 'light' | 'dark'

/**
 * Reactive dark mode / color scheme detection.
 * Updates automatically when the user switches between light and dark mode.
 *
 * @example
 * const { colorScheme, isDark } = useColorScheme()
 *
 * const bgColor = computed(() => isDark.value ? '#000' : '#FFF')
 */
export function useColorScheme() {
  const colorScheme = ref<ColorScheme>('light')
  const isDark = ref(false)
  let eventRevision = 0
  let isActive = true

  const applyColorScheme = (value: unknown) => {
    if (value !== 'light' && value !== 'dark') return
    colorScheme.value = value
    isDark.value = value === 'dark'
  }

  // Native bridges emit changes, but an app launched while the OS is already
  // dark must not report light until the next appearance transition.
  onMounted(() => {
    const revisionAtRequest = eventRevision
    void NativeBridge.invokeNativeModule('DeviceInfo', 'getInfo', [])
      .then((info: { colorScheme?: unknown } | undefined) => {
        // A newer push event is authoritative; do not let a delayed launch
        // snapshot roll the UI back to an older appearance.
        if (isActive && eventRevision === revisionAtRequest) {
          applyColorScheme(info?.colorScheme)
        }
      })
      .catch(() => undefined)
  })

  const unsubscribe = NativeBridge.onGlobalEvent(
    'colorScheme:change',
    (payload: { colorScheme?: unknown }) => {
      eventRevision++
      applyColorScheme(payload?.colorScheme)
    },
  )

  onUnmounted(() => {
    isActive = false
    unsubscribe()
  })

  return { colorScheme, isDark }
}
