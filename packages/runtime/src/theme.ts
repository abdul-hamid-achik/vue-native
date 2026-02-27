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
  inject, provide, computed, defineComponent, ref,
  type InjectionKey, type Ref, type ComputedRef,
} from '@vue/runtime-core'
import { createStyleSheet, type AnyStyle } from './stylesheet'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type ColorScheme = 'light' | 'dark'

export interface ThemeDefinition {
  light: Record<string, any>
  dark: Record<string, any>
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
export function createTheme<T extends Record<string, any>>(definition: { light: T, dark: T }) {
  const key: InjectionKey<ThemeContext<T>> = Symbol('vue-native-theme')

  const ThemeProvider = defineComponent({
    name: 'ThemeProvider',
    props: {
      initialColorScheme: {
        type: String as () => ColorScheme,
        default: 'light',
      },
    },
    setup(props, { slots }) {
      const colorScheme = ref<ColorScheme>(props.initialColorScheme) as Ref<ColorScheme>

      const theme = computed<T>(() => {
        return colorScheme.value === 'dark' ? definition.dark : definition.light
      })

      const ctx: ThemeContext<T> = {
        theme,
        colorScheme,
        toggleColorScheme: () => {
          colorScheme.value = colorScheme.value === 'light' ? 'dark' : 'light'
        },
        setColorScheme: (scheme: ColorScheme) => {
          colorScheme.value = scheme
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
  T extends Record<string, any>,
  S extends Record<string, AnyStyle>,
>(
  theme: ComputedRef<T> | Ref<T>,
  factory: (themeValue: T) => S,
): ComputedRef<{ readonly [K in keyof S]: Readonly<S[K]> }> {
  return computed(() => createStyleSheet(factory(theme.value))) as any
}
