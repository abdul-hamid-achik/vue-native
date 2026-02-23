/// <reference types="vite/client" />

/**
 * Type declaration for Vue Single File Components (.vue files).
 * This allows TypeScript to understand .vue imports.
 */
declare module '*.vue' {
  import type { DefineComponent } from 'vue'
  const component: DefineComponent<
    Record<string, never>,
    Record<string, never>,
    any
  >
  export default component
}

/**
 * Compile-time constants injected by @thelacanians/vue-native-vite-plugin.
 */
declare const __DEV__: boolean
declare const __PLATFORM__: string
