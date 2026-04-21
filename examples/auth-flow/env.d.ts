/// <reference types="vite/client" />

declare module '*.vue' {
  import type { DefineComponent } from 'vue'
  const component: DefineComponent<
    Record<string, never>,
    Record<string, never>,
    any
  >
  export default component
}

declare const __DEV__: boolean
declare const __PLATFORM__: string
