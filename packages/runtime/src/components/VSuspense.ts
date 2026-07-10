import {
  Suspense,
  defineAsyncComponent as vueDefineAsyncComponent,
} from '@vue/runtime-core'

/** Vue runtime-core Suspense, named for Vue Native's component convention. */
export const VSuspense = Suspense

/**
 * Vue's standard async-component helper. It accepts either a loader function
 * or an options object, unwraps dynamic-import defaults, supports delay and
 * timeout, and integrates with the renderer's Suspense boundary.
 */
export const defineAsyncComponent = vueDefineAsyncComponent

export type {
  AsyncComponentLoader,
  AsyncComponentOptions,
  SuspenseProps,
} from '@vue/runtime-core'

export default VSuspense
