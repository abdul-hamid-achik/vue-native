import { KeepAlive as VueKeepAlive } from '@vue/runtime-core'

/**
 * Vue's renderer-native KeepAlive implementation.
 *
 * Re-exporting runtime-core's component is important: it coordinates with the
 * custom renderer's activate/deactivate hooks and preserves component
 * instances, effects, and activated/deactivated lifecycle semantics.
 */
export const KeepAlive = VueKeepAlive

export type { KeepAliveProps } from '@vue/runtime-core'

export default KeepAlive
