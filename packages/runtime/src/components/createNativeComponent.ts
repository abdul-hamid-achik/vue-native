import { defineComponent, h } from '@vue/runtime-core'

/**
 * Escape hatch for embedding a custom native component.
 *
 * Returns a Vue component that renders the intrinsic native element `name`.
 * The native host must register a component factory for `name` (e.g.
 * `VueNativeViewController.registerComponent(name, factory:)` on iOS) before use.
 *
 * All attributes and the default slot are forwarded to the native element, so you
 * can pass props and style it like any other component.
 *
 * @example
 * ```ts
 * // After registering a native "MapGL" factory on the host:
 * const VMapGL = createNativeComponent('MapGL')
 * ```
 * ```vue
 * <VMapGL :style="{ flex: 1 }" region="..." @markerPress="onMarker" />
 * ```
 */
export function createNativeComponent(name: string) {
  return defineComponent({
    name: `Native${name}`,
    setup(_, { slots, attrs }) {
      return () => h(name, attrs, slots.default?.())
    },
  })
}
