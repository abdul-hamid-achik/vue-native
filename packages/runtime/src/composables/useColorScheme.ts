import { ref, onUnmounted } from '@vue/runtime-core'
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

  const unsubscribe = NativeBridge.onGlobalEvent(
    'colorScheme:change',
    (payload: { colorScheme: ColorScheme }) => {
      colorScheme.value = payload.colorScheme
      isDark.value = payload.colorScheme === 'dark'
    },
  )

  onUnmounted(unsubscribe)

  return { colorScheme, isDark }
}
