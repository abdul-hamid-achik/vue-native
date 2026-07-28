/**
 * Theme system for Vue Native — provides `createTheme`, `useTheme`, and
 * `createDynamicStyleSheet` for consistent design tokens and dark mode support.
 *
 * Uses Vue's provide/inject so theme values are reactive and scoped to
 * the component tree.
 *
 * @example
 * ```ts
 * // theme.ts
 * import { createTheme } from '@thelacanians/vue-native-runtime'
 *
 * export const { ThemeProvider, useTheme } = createTheme({
 *   light: {
 *     colors: { background: '#FFFFFF', text: '#1A1A1A', primary: '#007AFF' },
 *     spacing: { sm: 8, md: 16, lg: 24 },
 *   },
 *   dark: {
 *     colors: { background: '#1A1A1A', text: '#F5F5F5', primary: '#0A84FF' },
 *     spacing: { sm: 8, md: 16, lg: 24 },
 *   },
 * })
 * ```
 *
 * ```vue
 * <!-- App.vue -->
 * <script setup>
 * import { ThemeProvider } from './theme'
 * </script>
 * <template>
 *   <ThemeProvider>
 *     <MyScreen />
 *   </ThemeProvider>
 * </template>
 * ```
 *
 * ```vue
 * <!-- MyScreen.vue -->
 * <script setup>
 * import { useTheme } from './theme'
 * import { createDynamicStyleSheet } from '@thelacanians/vue-native-runtime'
 *
 * const { theme, colorScheme, toggleColorScheme } = useTheme()
 * const styles = createDynamicStyleSheet(theme, (t) => ({
 *   container: { flex: 1, backgroundColor: t.colors.background, padding: t.spacing.md },
 *   title: { fontSize: 24, color: t.colors.text },
 * }))
 * </script>
 * ```
 */

import {
  inject, provide, computed, defineComponent, ref, watch, onMounted,
  type InjectionKey, type Ref, type ComputedRef, type PropType,
} from '@vue/runtime-core'
import { createStyleSheet, type AnyStyle, type StyleSheet } from './stylesheet'
import { useColorScheme } from './composables/useColorScheme'
import { NativeBridge } from './bridge'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type ColorScheme = 'light' | 'dark'

export interface ThemeDefinition<T extends Record<string, unknown> = Record<string, unknown>> {
  light: T
  dark: T
}

export interface ThemeContext<T> {
  /** The current resolved theme object (reactive). */
  theme: ComputedRef<T>
  /** Current color scheme. */
  colorScheme: Ref<ColorScheme>
  /** Toggle between light and dark mode. */
  toggleColorScheme: () => void
  /** Set a specific color scheme. */
  setColorScheme: (scheme: ColorScheme) => void
}

// ---------------------------------------------------------------------------
// createTheme
// ---------------------------------------------------------------------------

/**
 * Create a theme system with light and dark variants.
 *
 * Returns a `ThemeProvider` component (wraps children with provide) and a
 * `useTheme` composable for consuming the theme in any descendant component.
 */
export function createTheme<T extends Record<string, unknown>>(definition: ThemeDefinition<T>) {
  const key: InjectionKey<ThemeContext<T>> = Symbol('vue-native-theme')

  const ThemeProvider = defineComponent({
    name: 'ThemeProvider',
    props: {
      initialColorScheme: {
        type: String as () => ColorScheme,
        default: 'light',
      },
      /**
       * When true, the color scheme follows the system appearance (via
       * `useColorScheme`) and updates automatically when the OS switches between
       * light and dark mode. `initialColorScheme` is used until the system
       * scheme is known. Default: false.
       */
      followSystem: {
        type: Boolean,
        default: false,
      },
      /**
       * Persist the color scheme across app launches (via AsyncStorage). Pass
       * `true` to use the default storage key, or a string to use a custom key.
       * An explicitly set scheme (setColorScheme/toggleColorScheme) is persisted
       * and restored on startup. Default: false.
       */
      persist: {
        type: [Boolean, String] as PropType<boolean | string>,
        default: false,
      },
    },
    setup(props, { slots }) {
      const colorScheme = ref(props.initialColorScheme as ColorScheme)
      const storageKey = typeof props.persist === 'string'
        ? props.persist
        : 'vue-native-color-scheme'

      // Sync with the system appearance when followSystem is enabled.
      if (props.followSystem) {
        const system = useColorScheme()
        colorScheme.value = system.colorScheme.value
        watch(system.colorScheme, (scheme) => {
          colorScheme.value = scheme
        })
      }

      // Restore a persisted scheme on mount (overrides initial/followSystem once
      // the user has made an explicit choice that was saved).
      if (props.persist) {
        onMounted(() => {
          NativeBridge.invokeNativeModule<string | null>('AsyncStorage', 'getItem', [storageKey])
            .then((stored) => {
              if (stored === 'light' || stored === 'dark') {
                colorScheme.value = stored
              }
            })
            .catch(() => {})
        })
      }

      function persistScheme(scheme: ColorScheme): void {
        if (props.persist) {
          NativeBridge.invokeNativeModule('AsyncStorage', 'setItem', [storageKey, scheme])
            .catch(() => {})
        }
      }

      const theme = computed<T>(() => {
        return colorScheme.value === 'dark' ? definition.dark : definition.light
      })

      const ctx: ThemeContext<T> = {
        theme,
        colorScheme,
        toggleColorScheme: () => {
          const next = colorScheme.value === 'light' ? 'dark' : 'light'
          colorScheme.value = next
          persistScheme(next)
        },
        setColorScheme: (scheme: ColorScheme) => {
          colorScheme.value = scheme
          persistScheme(scheme)
        },
      }

      provide(key, ctx)

      return () => slots.default?.()
    },
  })

  function useTheme(): ThemeContext<T> {
    const ctx = inject(key)
    if (!ctx) {
      throw new Error(
        '[Vue Native] useTheme() was called outside of a <ThemeProvider>. '
        + 'Wrap your app root with <ThemeProvider> to provide theme context.',
      )
    }
    return ctx
  }

  return { ThemeProvider, useTheme }
}

// ---------------------------------------------------------------------------
// createDynamicStyleSheet
// ---------------------------------------------------------------------------

/**
 * Create a computed stylesheet that automatically re-evaluates when the theme changes.
 *
 * @param theme - A reactive/computed theme object (from `useTheme().theme`)
 * @param factory - A function that receives the current theme and returns a style map
 * @returns A computed ref containing the frozen stylesheet
 *
 * @example
 * ```ts
 * const { theme } = useTheme()
 * const styles = createDynamicStyleSheet(theme, (t) => ({
 *   container: { flex: 1, backgroundColor: t.colors.background },
 *   text: { color: t.colors.text, fontSize: 16 },
 * }))
 * ```
 */
export function createDynamicStyleSheet<
  T extends Record<string, unknown>,
  S extends Record<string, AnyStyle>,
>(
  theme: ComputedRef<T> | Ref<T>,
  factory: (themeValue: T) => S,
): ComputedRef<StyleSheet<S>> {
  return computed(() => createStyleSheet(factory(theme.value)))
}
