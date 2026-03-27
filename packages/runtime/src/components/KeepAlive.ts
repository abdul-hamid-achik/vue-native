import {
  defineComponent,
  onUnmounted,
  watch,
  type VNode,
  type PropType,
} from '@vue/runtime-core'

interface CacheEntry {
  vnode: VNode
  key: string
}

interface KeepAliveProps {
  include?: string | RegExp | string[]
  exclude?: string | RegExp | string[]
  max?: number
}

function matches(pattern: string | RegExp | string[] | undefined, name: string): boolean {
  if (!pattern) return false
  if (typeof pattern === 'string') {
    return pattern === name
  }
  if (pattern instanceof RegExp) {
    return pattern.test(name)
  }
  if (Array.isArray(pattern)) {
    return pattern.includes(name)
  }
  return false
}

function getComponentName(vnode: VNode): string | undefined {
  const component = vnode.type
  if (typeof component === 'object' && component !== null && 'name' in component) {
    return (component as { name?: string }).name
  }
  if (typeof component === 'function') {
    return (component as { name?: string }).name
  }
  return undefined
}

export const KeepAlive = defineComponent({
  name: 'KeepAlive',
  props: {
    include: [String, RegExp, Array] as PropType<string | RegExp | string[] | undefined>,
    exclude: [String, RegExp, Array] as PropType<string | RegExp | string[] | undefined>,
    max: [Number, String] as PropType<number | string | undefined>,
  },
  setup(props: KeepAliveProps, { slots }) {
    const cache = new Map<string, CacheEntry>()
    const keys = new Set<string>()
    const maxCacheSize = typeof props.max === 'string' ? parseInt(props.max, 10) : props.max

    function pruneCache(filter: (name: string) => boolean) {
      cache.forEach((_, key) => {
        if (!filter(key)) {
          cache.delete(key)
          keys.delete(key)
        }
      })
    }

    function pruneCacheEntry(key: string) {
      cache.delete(key)
      keys.delete(key)
    }

    watch(
      () => [props.include, props.exclude],
      () => {
        if (!props.include && !props.exclude) return
        pruneCache((name) => {
          if (props.include && !matches(props.include, name)) return false
          if (props.exclude && matches(props.exclude, name)) return false
          return true
        })
      },
    )

    onUnmounted(() => {
      cache.clear()
      keys.clear()
    })

    return () => {
      const children = slots.default?.() ?? []
      if (!children.length) return children

      const vnode = children[0] as VNode
      const name = getComponentName(vnode) ?? String(vnode.type)
      const key = name

      // Check include/exclude
      if (props.include && !matches(props.include, name)) {
        return vnode
      }
      if (props.exclude && matches(props.exclude, name)) {
        return vnode
      }

      // Check cache
      const cached = cache.get(key)

      if (cached) {
        // Use cached vnode
        keys.delete(key)
        keys.add(key)
        return cached.vnode
      }

      // Create new cache entry
      if (maxCacheSize && cache.size >= maxCacheSize) {
        const firstKey = keys.values().next().value
        if (firstKey) {
          pruneCacheEntry(firstKey)
        }
      }

      cache.set(key, { vnode, key })
      keys.add(key)

      return vnode
    }
  },
})

// Mark as KeepAlive for Vue internal checks
;(KeepAlive as unknown as { isKeepAlive?: boolean }).isKeepAlive = true

export default KeepAlive
