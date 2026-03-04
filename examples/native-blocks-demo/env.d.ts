/// <reference types="vite/client" />

declare module '@thelacanians/vue-native-runtime' {
  import type { DefineComponent } from 'vue'
  
  export const VView: DefineComponent
  export const VText: DefineComponent
  export const VButton: DefineComponent
  export const VInput: DefineComponent
  export const VScrollView: DefineComponent
  export const VList: DefineComponent
  
  export function createStyleSheet(styles: any): any
}
