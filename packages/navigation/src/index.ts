import {
  ref,
  shallowRef,
  computed,
  watch,
  defineComponent,
  h,
  provide,
  inject,
  onUnmounted,
  type Component,
  type InjectionKey,
  type ComputedRef,
  type Ref,
  type ShallowRef,
} from '@vue/runtime-core'
import { NativeBridge } from '@thelacanians/vue-native-runtime'

// These globals exist at runtime in JavaScriptCore (polyfilled) but are not in ES2020 lib
declare const console: { warn(...args: any[]): void, error(...args: any[]): void }
declare function setTimeout(cb: () => void, ms: number): number
declare function clearTimeout(id: number): void
declare const __DEV__: boolean

// ─── Types ───────────────────────────────────────────────────────────────────

export interface RouteConfig {
  name: string
  component: Component
  options?: RouteOptions
}

export interface RouteOptions {
  title?: string
  headerShown?: boolean
  animation?: 'push' | 'modal' | 'fade' | 'none'
  tabBarLabel?: string
  tabBarIcon?: string
}

/**
 * @deprecated Use RouteOptions instead.
 */
export type NavigationOptions = RouteOptions

export interface NavigateOptions {
  /** Shared element IDs to animate between source and destination screens. */
  sharedElements?: string[]
}

export interface RouteEntry {
  config: RouteConfig
  params: Record<string, any>
  key: number
  /** Shared element IDs associated with this navigation transition. */
  sharedElements?: string[]
}

export interface RouteLocation {
  name: string
  params: Record<string, any>
  options: RouteOptions
}

export interface RouterInstance {
  /** The currently visible route entry (shallowRef). */
  currentRoute: ShallowRef<RouteEntry>
  /** Full navigation stack (ref). */
  stack: Ref<RouteEntry[]>
  /** Whether inactive screens should be unmounted to save memory. */
  unmountInactiveScreens: boolean
  /** Push a new route onto the stack. */
  navigate(name: string, params?: Record<string, any>, options?: NavigateOptions): Promise<void>
  /** Alias for navigate — preferred name in new API. */
  push(name: string, params?: Record<string, any>, options?: NavigateOptions): Promise<void>
  /** Pop the current route off the stack. */
  goBack(): Promise<void>
  /** Alias for goBack — preferred name in new API. */
  pop(): Promise<void>
  /** Replace the current route without adding to the stack. */
  replace(name: string, params?: Record<string, any>): Promise<void>
  /** Reset the stack to a single route. */
  reset(name: string, params?: Record<string, any>): Promise<void>
  /** Whether there is a previous route to go back to. */
  canGoBack: ComputedRef<boolean>
  /** Register a global before guard. Returns unsubscribe function. */
  beforeEach(guard: NavigationGuard): () => void
  /** Register a global resolve guard. Returns unsubscribe function. */
  beforeResolve(guard: NavigationGuard): () => void
  /** Register a global after hook. Returns unsubscribe function. */
  afterEach(guard: AfterGuard): () => void
  /** Handle an incoming deep link URL. Returns true if matched. */
  handleURL(url: string): boolean
  /** Serialize the current navigation state. */
  getState(): NavigationState
  /** Restore navigation state from a serialized snapshot. */
  restoreState(state: NavigationState): void
  /** Install into a Vue app (app.use(router)). */
  install(app: any): void
  /** Parent router, if this is a nested navigator. */
  parent?: RouterInstance
  /** Route map for state restoration validation. */
  _routeMap: Map<string, RouteConfig>
}

export type NavigationGuard = (
  to: RouteEntry,
  from: RouteEntry,
  next: (arg?: false | string) => void,
) => void | Promise<void>

export type AfterGuard = (to: RouteEntry, from: RouteEntry) => void

export interface LinkingConfig {
  prefixes: string[]
  config: { screens: Record<string, string> }
}

export interface RouterOptions {
  routes: RouteConfig[]
  linking?: LinkingConfig
  /**
   * When true, only the active screen and the one behind it (for back
   * animation) are mounted. All other inactive screens are unmounted to
   * save memory. Defaults to false for backward compatibility.
   */
  unmountInactiveScreens?: boolean
  /**
   * When true, navigation state is automatically saved to AsyncStorage
   * (debounced 300ms) and restored on creation. Defaults to false.
   */
  persistState?: boolean
  /**
   * Custom storage key for state persistence. Defaults to '__vue_native_nav_state__'.
   */
  persistKey?: string
  /**
   * Parent router for nested navigation. When set, this router operates
   * as a child navigator with its own independent stack.
   */
  parent?: RouterInstance
}

export interface NavigationState {
  stack: Array<{ name: string, params: Record<string, any> }>
  index: number
}

export interface DrawerScreenConfig {
  name: string
  label?: string
  icon?: string
  component: Component
}

export interface DrawerState {
  /** Whether the drawer is currently open. */
  isOpen: Ref<boolean>
  /** Open the drawer. */
  openDrawer: () => void
  /** Close the drawer. */
  closeDrawer: () => void
  /** Toggle the drawer open/closed. */
  toggleDrawer: () => void
}

export interface TabBarItem {
  name: string
  label?: string
  icon?: string
}

// ─── Injection Keys ───────────────────────────────────────────────────────────

const ROUTER_KEY: InjectionKey<RouterInstance> = Symbol('router')
const ROUTE_KEY: InjectionKey<ComputedRef<RouteLocation>> = Symbol('route')
const ROUTE_ENTRY_KEY: InjectionKey<Ref<number>> = Symbol('routeEntryKey')
const DRAWER_KEY: InjectionKey<DrawerState> = Symbol('drawer')
const NESTED_ROUTER_KEY: InjectionKey<RouterInstance> = Symbol('nestedRouter')

// ─── createRouter ─────────────────────────────────────────────────────────────

let keyCounter = 0

export function createRouter(optionsOrRoutes: RouterOptions | RouteConfig[]): RouterInstance {
  // Support both createRouter([...routes]) and createRouter({ routes, linking })
  const options: RouterOptions = Array.isArray(optionsOrRoutes)
    ? { routes: optionsOrRoutes }
    : optionsOrRoutes

  const {
    routes,
    linking: linkingConfig,
    unmountInactiveScreens: _unmountInactive = false,
    persistState: _persistState = false,
    persistKey = '__vue_native_nav_state__',
    parent: parentRouter,
  } = options

  if (routes.length === 0) {
    throw new Error('[vue-native/navigation] createRouter requires at least one route')
  }

  const routeMap = new Map(routes.map(r => [r.name, r]))

  const initialEntry: RouteEntry = { config: routes[0], params: {}, key: keyCounter++ }
  const stack = ref<RouteEntry[]>([initialEntry])
  const currentRoute = shallowRef<RouteEntry>(initialEntry)

  const canGoBack: ComputedRef<boolean> = computed(() => stack.value.length > 1)

  // ── Navigation Guards ──────────────────────────────────────────────────────

  const beforeGuards: NavigationGuard[] = []
  const resolveGuards: NavigationGuard[] = []
  const afterGuards: AfterGuard[] = []

  function beforeEach(guard: NavigationGuard): () => void {
    beforeGuards.push(guard)
    return () => {
      const i = beforeGuards.indexOf(guard)
      if (i > -1) beforeGuards.splice(i, 1)
    }
  }

  function beforeResolve(guard: NavigationGuard): () => void {
    resolveGuards.push(guard)
    return () => {
      const i = resolveGuards.indexOf(guard)
      if (i > -1) resolveGuards.splice(i, 1)
    }
  }

  function afterEach(guard: AfterGuard): () => void {
    afterGuards.push(guard)
    return () => {
      const i = afterGuards.indexOf(guard)
      if (i > -1) afterGuards.splice(i, 1)
    }
  }

  async function runGuards(
    guards: NavigationGuard[],
    to: RouteEntry,
    from: RouteEntry,
  ): Promise<false | string | void> {
    for (const guard of guards) {
      const result = await new Promise<false | string | void>((resolve) => {
        let called = false
        const guardReturn = guard(to, from, (arg) => {
          if (!called) {
            called = true
            resolve(arg === false ? false : typeof arg === 'string' ? arg : undefined)
          }
        })
        // If guard returns a promise and doesn't call next(), auto-resolve
        if (guardReturn instanceof Promise) {
          guardReturn.then(() => {
            if (!called) {
              called = true
              resolve(undefined)
            }
          }).catch((err) => {
            if (!called) {
              called = true
              console.error('[VueNative] Navigation guard error:', err)
              resolve(false)
            }
          })
        }
      })
      if (result === false) return false
      if (typeof result === 'string') return result
    }
  }

  // ── Navigation methods ─────────────────────────────────────────────────────

  async function navigate(name: string, params: Record<string, any> = {}, options?: NavigateOptions, _redirectDepth = 0): Promise<void> {
    if (_redirectDepth > 20) {
      console.warn('[vue-native/navigation] Circular redirect detected (depth > 20), aborting navigation')
      return
    }

    const config = routeMap.get(name)
    if (!config) {
      console.warn(`[vue-native/navigation] Route "${name}" not found`)
      return
    }
    const to: RouteEntry = {
      config,
      params,
      key: keyCounter++,
      sharedElements: options?.sharedElements,
    }
    const from = currentRoute.value

    // Run beforeEach guards
    const beforeResult = await runGuards(beforeGuards, to, from)
    if (beforeResult === false) return
    if (typeof beforeResult === 'string') {
      return navigate(beforeResult, params, undefined, _redirectDepth + 1)
    }

    // Run beforeResolve guards
    const resolveResult = await runGuards(resolveGuards, to, from)
    if (resolveResult === false) return
    if (typeof resolveResult === 'string') {
      return navigate(resolveResult, params, undefined, _redirectDepth + 1)
    }

    // Commit navigation
    stack.value = [...stack.value, to]
    currentRoute.value = to

    // Run afterEach hooks
    afterGuards.forEach(guard => guard(to, from))
  }

  async function goBack(): Promise<void> {
    if (stack.value.length <= 1) return
    const newStack = stack.value.slice(0, -1)
    const to = newStack[newStack.length - 1]
    const from = currentRoute.value

    // Run beforeEach guards
    const beforeResult = await runGuards(beforeGuards, to, from)
    if (beforeResult === false) return
    if (typeof beforeResult === 'string') {
      return navigate(beforeResult)
    }

    // Run beforeResolve guards
    const resolveResult = await runGuards(resolveGuards, to, from)
    if (resolveResult === false) return
    if (typeof resolveResult === 'string') {
      return navigate(resolveResult)
    }

    stack.value = newStack
    currentRoute.value = to

    // Run afterEach hooks
    afterGuards.forEach(guard => guard(to, from))
  }

  async function replace(name: string, params: Record<string, any> = {}, _redirectDepth = 0): Promise<void> {
    if (_redirectDepth > 20) {
      console.warn('[vue-native/navigation] Circular redirect detected (depth > 20), aborting navigation')
      return
    }

    const config = routeMap.get(name)
    if (!config) {
      console.warn(`[vue-native/navigation] Route "${name}" not found`)
      return
    }
    const to: RouteEntry = { config, params, key: keyCounter++ }
    const from = currentRoute.value

    const beforeResult = await runGuards(beforeGuards, to, from)
    if (beforeResult === false) return
    if (typeof beforeResult === 'string') {
      return navigate(beforeResult, params, undefined, _redirectDepth + 1)
    }

    const resolveResult = await runGuards(resolveGuards, to, from)
    if (resolveResult === false) return
    if (typeof resolveResult === 'string') {
      return navigate(resolveResult, params, undefined, _redirectDepth + 1)
    }

    stack.value = [...stack.value.slice(0, -1), to]
    currentRoute.value = to

    afterGuards.forEach(guard => guard(to, from))
  }

  async function reset(name: string, params: Record<string, any> = {}, _redirectDepth = 0): Promise<void> {
    if (_redirectDepth > 20) {
      console.warn('[vue-native/navigation] Circular redirect detected (depth > 20), aborting navigation')
      return
    }

    const config = routeMap.get(name)
    if (!config) {
      console.warn(`[vue-native/navigation] Route "${name}" not found`)
      return
    }
    const to: RouteEntry = { config, params, key: keyCounter++ }
    const from = currentRoute.value

    const beforeResult = await runGuards(beforeGuards, to, from)
    if (beforeResult === false) return
    if (typeof beforeResult === 'string') {
      return navigate(beforeResult, params, undefined, _redirectDepth + 1)
    }

    const resolveResult = await runGuards(resolveGuards, to, from)
    if (resolveResult === false) return
    if (typeof resolveResult === 'string') {
      return navigate(resolveResult, params, undefined, _redirectDepth + 1)
    }

    stack.value = [to]
    currentRoute.value = to

    afterGuards.forEach(guard => guard(to, from))
  }

  // ── Deep Linking ───────────────────────────────────────────────────────────

  function matchPattern(pattern: string, path: string): Record<string, string> | null {
    const patternParts = pattern.split('/').filter(Boolean)
    const pathParts = path.split('/').filter(Boolean)
    if (patternParts.length !== pathParts.length) return null
    const params: Record<string, string> = {}
    for (let i = 0; i < patternParts.length; i++) {
      if (patternParts[i].startsWith(':')) {
        params[patternParts[i].slice(1)] = pathParts[i]
      } else if (patternParts[i] !== pathParts[i]) {
        return null
      }
    }
    return params
  }

  function handleURL(url: string): boolean {
    if (!linkingConfig) return false

    if (url.length > 2048) {
      console.warn('[VueNative] URL too long, ignoring:', url.slice(0, 100) + '...')
      return false
    }

    // Strip prefix (sort by length descending so longest prefix matches first)
    let path = url
    const sortedPrefixes = [...linkingConfig.prefixes].sort((a, b) => b.length - a.length)
    for (const prefix of sortedPrefixes) {
      if (url.startsWith(prefix)) {
        path = url.slice(prefix.length)
        break
      }
    }

    // Strip query string and fragment before matching
    const queryParams: Record<string, string> = {}
    const hashIndex = path.indexOf('#')
    if (hashIndex !== -1) {
      path = path.slice(0, hashIndex)
    }
    const qIndex = path.indexOf('?')
    if (qIndex !== -1) {
      const queryString = path.slice(qIndex + 1)
      path = path.slice(0, qIndex)
      // Parse query params
      for (const pair of queryString.split('&')) {
        const eqIdx = pair.indexOf('=')
        if (eqIdx !== -1) {
          queryParams[decodeURIComponent(pair.slice(0, eqIdx))] = decodeURIComponent(pair.slice(eqIdx + 1))
        } else if (pair.length > 0) {
          queryParams[decodeURIComponent(pair)] = ''
        }
      }
    }

    // Remove leading/trailing slashes
    path = path.replace(/^\/+|\/+$/g, '')

    // Match against screen patterns
    for (const [screenName, pattern] of Object.entries(linkingConfig.config.screens)) {
      const params = matchPattern(pattern, path)
      if (params !== null) {
        navigate(screenName, { ...queryParams, ...params })
        return true
      }
    }
    return false
  }

  // ── State Persistence ──────────────────────────────────────────────────────

  function getState(): NavigationState {
    if (typeof __DEV__ !== 'undefined' && __DEV__) {
      for (const entry of stack.value) {
        if (entry.params) {
          for (const [key, val] of Object.entries(entry.params)) {
            if (typeof val === 'function' || typeof val === 'symbol') {
              console.warn(
                `[vue-native/navigation] Route "${entry.config.name}" has non-serializable param "${key}" (${typeof val}). `
                + 'This value will be lost during state persistence.',
              )
            }
          }
        }
      }
    }

    return {
      stack: stack.value.map(entry => ({
        name: entry.config.name,
        params: entry.params,
      })),
      index: stack.value.length - 1,
    }
  }

  function restoreState(state: NavigationState): void {
    if (!state || !Array.isArray(state.stack) || state.stack.length === 0) {
      console.warn('[vue-native/navigation] Invalid state, ignoring restoreState')
      return
    }

    // Validate all routes exist; if any are stale, reset to initial
    const entries: RouteEntry[] = []
    for (const item of state.stack) {
      const config = routeMap.get(item.name)
      if (!config) {
        console.warn(`[vue-native/navigation] Route "${item.name}" not found in restoreState, resetting to initial`)
        return // stale state — keep current state
      }
      entries.push({ config, params: item.params ?? {}, key: keyCounter++ })
    }

    stack.value = entries
    const idx = typeof state.index === 'number' && state.index >= 0 && state.index < entries.length
      ? state.index
      : entries.length - 1
    currentRoute.value = entries[idx]
  }

  // Debounced auto-persist
  let persistTimer: ReturnType<typeof setTimeout> | null = null
  function schedulePersist(): void {
    if (!_persistState) return
    if (persistTimer !== null) clearTimeout(persistTimer)
    persistTimer = setTimeout(() => {
      persistTimer = null
      const stateJson = JSON.stringify(getState())
      NativeBridge.invokeNativeModule('AsyncStorage', 'setItem', [persistKey, stateJson])
        .catch(() => {})
    }, 300)
  }

  // Watch for navigation changes to auto-persist.
  // The `restoreComplete` flag prevents the watcher from persisting stale state
  // before the async restore from storage has finished — avoiding a race where
  // an early navigation overwrites the persisted state before it's been read.
  if (_persistState) {
    let restoreComplete = false
    let restoring = false

    watch(() => stack.value, () => {
      if (restoreComplete && !restoring) schedulePersist()
    }, { deep: true })

    // Restore state on creation
    restoring = true
    NativeBridge.invokeNativeModule('AsyncStorage', 'getItem', [persistKey])
      .then((json: any) => {
        if (typeof json === 'string' && json.length > 0) {
          try {
            const saved = JSON.parse(json) as NavigationState
            restoreState(saved)
          } catch {
            // corrupted data — ignore
          }
        }
      })
      .catch(() => {})
      .finally(() => {
        restoring = false
        restoreComplete = true
      })
  }

  // ── Router instance ────────────────────────────────────────────────────────

  const router: RouterInstance = {
    currentRoute,
    stack,
    unmountInactiveScreens: _unmountInactive,
    canGoBack,
    navigate,
    push: (name: string, params?: Record<string, any>, options?: NavigateOptions) => navigate(name, params, options),
    goBack,
    pop: goBack,
    replace,
    reset,
    beforeEach,
    beforeResolve,
    afterEach,
    handleURL,
    getState,
    restoreState,
    parent: parentRouter,
    _routeMap: routeMap,
    install(app: any) {
      app.provide(ROUTER_KEY, router)
    },
  }

  // ── Deep link listeners ────────────────────────────────────────────────────

  if (linkingConfig) {
    // Check for initial URL that launched the app
    NativeBridge.invokeNativeModule('Linking', 'getInitialURL', [])
      .then((url: any) => { if (url) handleURL(url as string) })
      .catch(() => {})

    // Listen for incoming URLs while app is running
    NativeBridge.onGlobalEvent('url', (payload: any) => {
      if (payload?.url) handleURL(payload.url as string)
    })
  }

  return router
}

// ─── Nested Router Provider ───────────────────────────────────────────────────

/**
 * Internal component that provides a nested router context.
 * Used by TabScreen/DrawerScreen to scope a child RouterView to a nested router.
 */
const _NestedRouterProvider = defineComponent({
  name: 'NestedRouterProvider',
  props: {
    router: { type: Object as () => RouterInstance, required: true },
  },
  setup(props, { slots }) {
    provide(NESTED_ROUTER_KEY, props.router)
    return () => slots.default?.()
  },
})

// ─── useRouter / useRoute ─────────────────────────────────────────────────────

export function useRouter(): RouterInstance {
  // Prefer the nearest nested router if available
  const nested = inject(NESTED_ROUTER_KEY, null)
  if (nested) return nested

  const router = inject(ROUTER_KEY)
  if (!router) {
    throw new Error(
      '[vue-native/navigation] useRouter() called outside of router context. '
      + 'Make sure app.use(router) is called.',
    )
  }
  return router
}

/**
 * Returns a ComputedRef<RouteLocation> for the nearest enclosing route screen.
 * When used inside RouterView, each screen gets its own route context.
 * Falls back to the global router's currentRoute if no per-screen context exists.
 */
export function useRoute(): ComputedRef<RouteLocation> {
  const perScreenRoute = inject<ComputedRef<RouteLocation>>(ROUTE_KEY)
  if (perScreenRoute) return perScreenRoute

  // Fallback: derive from global router (works outside RouterView)
  const router = useRouter()
  return computed<RouteLocation>(() => ({
    name: router.currentRoute.value.config.name,
    params: router.currentRoute.value.params,
    options: router.currentRoute.value.config.options ?? {},
  }))
}

// ─── Screen Lifecycle Composables ─────────────────────────────────────────────

/**
 * Calls the callback when the screen gains focus (becomes the top route).
 * Must be called inside a component rendered by RouterView.
 */
export function onScreenFocus(callback: () => void): void {
  const router = useRouter()
  const entryKey = inject(ROUTE_ENTRY_KEY)

  let isFocused = false
  const stop = watch(
    () => router.currentRoute.value,
    (current) => {
      const nowFocused = entryKey ? current.key === entryKey.value : false
      if (nowFocused && !isFocused) {
        isFocused = true
        callback()
      } else if (!nowFocused) {
        isFocused = false
      }
    },
    { immediate: true },
  )
  onUnmounted(stop)
}

/**
 * Calls the callback when the screen loses focus (is no longer the top route).
 * Must be called inside a component rendered by RouterView.
 */
export function onScreenBlur(callback: () => void): void {
  const router = useRouter()
  const entryKey = inject(ROUTE_ENTRY_KEY)

  let isFocused = false
  const stop = watch(
    () => router.currentRoute.value,
    (current) => {
      const nowFocused = entryKey ? current.key === entryKey.value : false
      if (!nowFocused && isFocused) {
        callback()
      }
      isFocused = nowFocused
    },
    { immediate: true },
  )
  onUnmounted(stop)
}

// ─── Internal: RouteProvider ──────────────────────────────────────────────────

/**
 * Provides per-screen route context so useRoute() returns the correct route
 * even when multiple screens are mounted simultaneously in the stack.
 */
const RouteProvider = defineComponent({
  name: 'RouteProvider',
  props: {
    entry: { type: Object as () => RouteEntry, required: true },
  },
  setup(props, { slots }) {
    const routeLocation = computed<RouteLocation>(() => ({
      name: props.entry.config.name,
      params: props.entry.params,
      options: props.entry.config.options ?? {},
    }))
    const entryKey = ref(props.entry.key)
    provide(ROUTE_KEY, routeLocation)
    provide(ROUTE_ENTRY_KEY, entryKey)
    return () => slots.default?.()
  },
})

// ─── RouterView ───────────────────────────────────────────────────────────────

/**
 * Renders the router's navigation stack.
 *
 * All routes in the history are mounted simultaneously (so back navigation
 * is instant — no remounting). Only the top screen is fully visible; screens
 * below it are slid off to the right via `transform: [{ translateX: 1000 }]`.
 *
 * The top screen slides in from the right on push and slides back out to the
 * right on pop, giving the standard iOS "slide" push/pop feel.
 *
 * Per-screen route context is provided via RouteProvider so that useRoute()
 * inside each screen component returns the correct route.
 *
 * @example
 * <RouterView />
 */
export const RouterView = defineComponent({
  name: 'RouterView',
  setup() {
    const router = useRouter()

    return () => {
      const entries = router.stack.value
      // When unmountInactiveScreens is enabled, only render the top screen
      // and the one directly behind it (to support back-swipe animation).
      const visibleEntries = router.unmountInactiveScreens && entries.length > 2
        ? entries.slice(-2)
        : entries

      return h(
        'VView',
        {
          style: {
            flex: 1,
            overflow: 'hidden',
            position: 'relative',
          },
        },
        visibleEntries.map((entry, index) => {
          const isTop = index === visibleEntries.length - 1
          // Non-top screens are pushed off-screen to the left (−50 % / −50 pt
          // is enough to hide them; using a large value like 1000 also works
          // but −50 avoids any chance of a flash on very wide devices).
          // The top screen is at translateX: 0 (its natural position).
          return h(
            'VView',
            {
              key: entry.key,
              style: {
                position: 'absolute',
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                transform: isTop ? [] : [{ translateX: -50 }],
                // Hide off-screen screens from the accessibility tree and
                // prevent touch events from reaching them.
                opacity: isTop ? 1 : 0,
              },
            },
            [
              h(RouteProvider, { entry }, () =>
                h(entry.config.component as any, { routeParams: entry.params }),
              ),
            ],
          )
        }),
      )
    }
  },
})

// ─── VNavigationBar ───────────────────────────────────────────────────────────

/**
 * A navigation header bar with a centered title and an optional back button.
 * Renders as a 44pt tall UIKit-style navigation bar at the top of a screen.
 *
 * @example
 * const router = useRouter()
 * const canGoBack = router.canGoBack
 *
 * <VNavigationBar
 *   title="Settings"
 *   :show-back="canGoBack"
 *   @back="router.pop()"
 * />
 */
export const VNavigationBar = defineComponent({
  name: 'VNavigationBar',
  props: {
    /** Screen title, rendered centered in the bar. */
    title: { type: String, default: '' },
    /** Whether to show the back chevron + backTitle on the left. */
    showBack: { type: Boolean, default: false },
    /** Text shown next to the back chevron. Defaults to "Back". */
    backTitle: { type: String, default: 'Back' },
    /** Background colour of the bar. */
    backgroundColor: { type: String, default: '#FFFFFF' },
    /** Colour used for the back button text. */
    tintColor: { type: String, default: '#007AFF' },
    /** Colour of the title text. */
    titleColor: { type: String, default: '#000000' },
  },
  emits: ['back'],
  setup(props, { emit }) {
    return () =>
      h(
        'VView',
        {
          style: {
            flexDirection: 'row',
            alignItems: 'center',
            height: 44,
            backgroundColor: props.backgroundColor,
            paddingHorizontal: 16,
            borderBottomWidth: 0.5,
            borderBottomColor: '#C8C8CC',
          },
        },
        [
          // ── Left slot: back button or spacer ──────────────────────────────
          props.showBack
            ? h(
                'VButton',
                {
                  style: {
                    flexDirection: 'row',
                    alignItems: 'center',
                    paddingHorizontal: 0,
                    paddingVertical: 8,
                    minWidth: 60,
                    backgroundColor: 'transparent',
                  },
                  onPress: () => emit('back'),
                },
                () =>
                  h(
                    'VText',
                    { style: { color: props.tintColor, fontSize: 17 } },
                    () => `\u2039 ${props.backTitle}`,
                  ),
              )
            : h('VView', { style: { minWidth: 60 } }),

          // ── Center: title ────────────────────────────────────────────────
          h('VView', { style: { flex: 1, alignItems: 'center' } }, [
            h(
              'VText',
              {
                style: {
                  fontSize: 17,
                  fontWeight: '600',
                  color: props.titleColor,
                },
              },
              () => props.title,
            ),
          ]),

          // ── Right slot: spacer to balance left side ───────────────────────
          h('VView', { style: { minWidth: 60 } }),
        ],
      )
  },
})

// ─── VTabBar ─────────────────────────────────────────────────────────────────

/**
 * A bottom tab bar that lets users switch between top-level sections.
 * Uses v-model (modelValue / update:modelValue) to track the active tab name.
 *
 * @example
 * const activeTab = ref('home')
 *
 * <VTabBar
 *   :tabs="[
 *     { name: 'home',     label: 'Home',     icon: '🏠' },
 *     { name: 'settings', label: 'Settings', icon: '⚙️' },
 *   ]"
 *   v-model="activeTab"
 * />
 */
export const VTabBar = defineComponent({
  name: 'VTabBar',
  props: {
    /** Array of tab descriptors. */
    tabs: { type: Array as () => TabBarItem[], required: true },
    /** Name of the currently active tab (v-model). */
    modelValue: { type: String, default: '' },
    /** Text / icon colour for the active tab. */
    activeColor: { type: String, default: '#007AFF' },
    /** Text / icon colour for inactive tabs. */
    inactiveColor: { type: String, default: '#8E8E93' },
    /** Background colour of the tab bar. */
    backgroundColor: { type: String, default: '#F9F9F9' },
  },
  emits: ['update:modelValue'],
  setup(props, { emit }) {
    return () =>
      h(
        'VView',
        {
          style: {
            flexDirection: 'row',
            backgroundColor: props.backgroundColor,
            borderTopWidth: 0.5,
            borderTopColor: '#C8C8CC',
            paddingBottom: 4,
          },
        },
        props.tabs.map((tab) => {
          const isActive = props.modelValue === tab.name
          return h(
            'VButton',
            {
              key: tab.name,
              style: {
                flex: 1,
                alignItems: 'center',
                paddingVertical: 8,
                backgroundColor: 'transparent',
              },
              onPress: () => emit('update:modelValue', tab.name),
            },
            () => [
              // Icon (optional)
              tab.icon != null
                ? h(
                    'VText',
                    {
                      style: {
                        fontSize: 24,
                        marginBottom: 2,
                        color: isActive ? props.activeColor : props.inactiveColor,
                      },
                    },
                    () => tab.icon as string,
                  )
                : null,
              // Label
              h(
                'VText',
                {
                  style: {
                    fontSize: 10,
                    color: isActive ? props.activeColor : props.inactiveColor,
                    fontWeight: isActive ? '600' : '400',
                  },
                },
                () => tab.label ?? tab.name,
              ),
            ],
          )
        }),
      )
  },
})

// ─── createTabNavigator ───────────────────────────────────────────────────────

export interface TabScreenConfig {
  name: string
  label?: string
  icon?: string
  component: Component
  /**
   * When true, the tab content is not mounted until the tab is first visited.
   * Defaults to false (mounted immediately).
   */
  lazy?: boolean
}

/**
 * Create a self-contained tab-based navigator.
 *
 * Returns a `TabNavigator` component and a reactive `activeTab` ref.
 * Each screen is declared using `TabScreen` props passed directly to
 * `TabNavigator` via the `screens` prop, keeping the setup ergonomic
 * without requiring render-function slot tricks.
 *
 * @example
 * const { TabNavigator } = createTabNavigator()
 *
 * // In your render / template:
 * <TabNavigator
 *   :screens="[
 *     { name: 'home',     label: 'Home',     icon: '🏠', component: HomeView },
 *     { name: 'settings', label: 'Settings', icon: '⚙️', component: SettingsView },
 *   ]"
 * />
 */
export function createTabNavigator() {
  const activeTab = ref<string>('')
  /** Tracks which tabs have been visited (for lazy mounting). */
  const visitedTabs = new Set<string>()

  const TabNavigator = defineComponent({
    name: 'TabNavigator',
    props: {
      /** Ordered list of tab screen descriptors. */
      screens: { type: Array as () => TabScreenConfig[], required: true },
      /** Which tab is shown first. Defaults to the first screen. */
      initialTab: { type: String, default: '' },
      /** Active tab icon / label colour. */
      activeColor: { type: String, default: '#007AFF' },
      /** Inactive tab icon / label colour. */
      inactiveColor: { type: String, default: '#8E8E93' },
      /** Background colour of the tab bar. */
      tabBarBackgroundColor: { type: String, default: '#F9F9F9' },
    },
    setup(props) {
      // Initialise activeTab the first time we have screens available.
      // We do this reactively inside the render function so it works even
      // when the component tree is set up before screens are known.
      return () => {
        const screens = props.screens
        if (screens.length === 0) return null

        // Lazy initialisation of the active tab.
        if (activeTab.value === '') {
          activeTab.value = props.initialTab || screens[0].name
        }

        // Mark the active tab as visited for lazy loading.
        visitedTabs.add(activeTab.value)

        const tabs: TabBarItem[] = screens.map(s => ({
          name: s.name,
          label: s.label,
          icon: s.icon,
        }))

        // Build screen children: all non-lazy tabs are always mounted;
        // lazy tabs are mounted only after their first visit.
        // Only the active tab is visible (flex: 1); others are hidden (size 0).
        const screenChildren = screens
          .filter(s => !s.lazy || visitedTabs.has(s.name))
          .map((s) => {
            const isActive = s.name === activeTab.value
            return h(
              'VView',
              {
                key: s.name,
                style: isActive
                  ? { flex: 1 }
                  : { width: 0, height: 0, overflow: 'hidden' },
              },
              [h(s.component as any)],
            )
          })

        return h('VView', { style: { flex: 1 } }, [
          // ── Screen area ─────────────────────────────────────────────────
          h('VView', { style: { flex: 1 } }, screenChildren),
          // ── Tab bar ──────────────────────────────────────────────────────
          h(VTabBar, {
            tabs,
            'modelValue': activeTab.value,
            'activeColor': props.activeColor,
            'inactiveColor': props.inactiveColor,
            'backgroundColor': props.tabBarBackgroundColor,
            'onUpdate:modelValue': (name: string) => {
              activeTab.value = name
            },
          }),
        ])
      }
    },
  })

  // ── TabScreen is a declarative config component ───────────────────────────
  // It renders nothing itself; its props are read by the parent TabNavigator.
  // Provided for ergonomic JSX / template usage where individual screens
  // can be defined as self-documenting child elements.
  const TabScreen = defineComponent({
    name: 'TabScreen',
    props: {
      name: { type: String, required: true },
      label: { type: String, default: undefined },
      icon: { type: String, default: undefined },
      component: { type: Object as () => Component, required: true },
      lazy: { type: Boolean, default: false },
    },
    setup() {
      // Intentionally renders nothing — used as a declarative config child.
      return () => null
    },
  })

  return { TabNavigator, TabScreen, activeTab }
}

// ─── createDrawerNavigator ────────────────────────────────────────────────────

/**
 * Create a drawer-based navigator with a sliding panel.
 *
 * Returns `DrawerNavigator`, `DrawerScreen`, and `useDrawer` composable.
 * The drawer slides in from the left (or right) as a JS-animated panel.
 *
 * @example
 * const { DrawerNavigator, useDrawer } = createDrawerNavigator()
 *
 * // In your render:
 * <DrawerNavigator
 *   :screens="[
 *     { name: 'home',  label: 'Home',  icon: 'H', component: HomeView },
 *     { name: 'about', label: 'About', icon: 'A', component: AboutView },
 *   ]"
 *   :drawerContent="SideMenu"
 * />
 */
export function createDrawerNavigator() {
  const isOpen = ref(false)
  const activeScreen = ref<string>('')

  function openDrawer(): void {
    isOpen.value = true
  }
  function closeDrawer(): void {
    isOpen.value = false
  }
  function toggleDrawer(): void {
    isOpen.value = !isOpen.value
  }

  const drawerState: DrawerState = { isOpen, openDrawer, closeDrawer, toggleDrawer }

  const DrawerNavigator = defineComponent({
    name: 'DrawerNavigator',
    props: {
      /** Ordered list of drawer screen descriptors. */
      screens: { type: Array as () => DrawerScreenConfig[], required: true },
      /** Optional custom drawer content component. Receives screens and activeScreen as props. */
      drawerContent: { type: Object as () => Component, default: undefined },
      /** Width of the drawer panel in points. */
      drawerWidth: { type: Number, default: 280 },
      /** Which side the drawer slides from. */
      drawerPosition: { type: String as () => 'left' | 'right', default: 'left' },
      /** Which screen is initially shown. Defaults to first. */
      initialScreen: { type: String, default: '' },
      /** Background colour of the default drawer menu. */
      drawerBackgroundColor: { type: String, default: '#FFFFFF' },
      /** Colour of the overlay behind the drawer when open. */
      overlayColor: { type: String, default: 'rgba(0,0,0,0.4)' },
    },
    setup(props) {
      // Provide drawer state so useDrawer() works inside children
      provide(DRAWER_KEY, drawerState)

      return () => {
        const screens = props.screens
        if (screens.length === 0) return null

        // Lazy initialise
        if (activeScreen.value === '') {
          activeScreen.value = props.initialScreen || screens[0].name
        }

        const _current = screens.find(s => s.name === activeScreen.value) ?? screens[0]
        const isLeft = props.drawerPosition === 'left'

        // ── Default drawer content (list of screens) ────────────────────
        const drawerMenu = props.drawerContent
          ? h(props.drawerContent as any, {
              screens,
              activeScreen: activeScreen.value,
              onSelect: (name: string) => {
                activeScreen.value = name
                closeDrawer()
              },
            })
          : h('VView', { style: { flex: 1, paddingTop: 60, paddingHorizontal: 16 } },
              screens.map(s =>
                h('VButton', {
                  key: s.name,
                  style: {
                    paddingVertical: 14,
                    paddingHorizontal: 12,
                    backgroundColor: s.name === activeScreen.value ? '#E8E8ED' : 'transparent',
                    borderRadius: 8,
                    marginBottom: 4,
                  },
                  onPress: () => {
                    activeScreen.value = s.name
                    closeDrawer()
                  },
                }, () =>
                  h('VView', { style: { flexDirection: 'row', alignItems: 'center' } }, [
                    s.icon != null
                      ? h('VText', { style: { fontSize: 18, marginRight: 12 } }, () => s.icon as string)
                      : null,
                    h('VText', {
                      style: {
                        fontSize: 16,
                        fontWeight: s.name === activeScreen.value ? '600' : '400',
                        color: '#000000',
                      },
                    }, () => s.label ?? s.name),
                  ]),
                ),
              ),
            )

        // ── Drawer panel ────────────────────────────────────────────────
        const drawerTranslateX = isOpen.value
          ? 0
          : isLeft ? -props.drawerWidth : props.drawerWidth

        const drawerPanel = h('VView', {
          style: {
            position: 'absolute',
            top: 0,
            bottom: 0,
            width: props.drawerWidth,
            ...(isLeft ? { left: 0 } : { right: 0 }),
            transform: [{ translateX: drawerTranslateX }],
            backgroundColor: props.drawerBackgroundColor,
            zIndex: 20,
          },
        }, [drawerMenu])

        // ── Overlay (only visible when open) ────────────────────────────
        const overlay = isOpen.value
          ? h('VButton', {
              style: {
                position: 'absolute',
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                backgroundColor: props.overlayColor,
                zIndex: 10,
              },
              onPress: closeDrawer,
            })
          : null

        // ── Screen content ──────────────────────────────────────────────
        // All screens are mounted but only active one is visible
        const screenChildren = screens.map((s) => {
          const isActive = s.name === activeScreen.value
          return h('VView', {
            key: s.name,
            style: isActive
              ? { flex: 1 }
              : { width: 0, height: 0, overflow: 'hidden' },
          }, [h(s.component as any)])
        })

        return h('VView', { style: { flex: 1 } }, [
          // Main content
          h('VView', { style: { flex: 1 } }, screenChildren),
          // Overlay
          overlay,
          // Drawer panel
          drawerPanel,
        ])
      }
    },
  })

  // ── DrawerScreen: declarative config component ────────────────────────────
  const DrawerScreen = defineComponent({
    name: 'DrawerScreen',
    props: {
      name: { type: String, required: true },
      label: { type: String, default: undefined },
      icon: { type: String, default: undefined },
      component: { type: Object as () => Component, required: true },
    },
    setup() {
      return () => null
    },
  })

  return { DrawerNavigator, DrawerScreen, useDrawer: () => drawerState, activeScreen }
}

// ─── useDrawer ────────────────────────────────────────────────────────────────

/**
 * Access the nearest drawer navigator state.
 * Must be called inside a component rendered within a DrawerNavigator.
 *
 * @example
 * const { openDrawer, closeDrawer, toggleDrawer, isOpen } = useDrawer()
 */
export function useDrawer(): DrawerState {
  const drawer = inject(DRAWER_KEY)
  if (!drawer) {
    throw new Error(
      '[vue-native/navigation] useDrawer() called outside of drawer context. '
      + 'Make sure this component is rendered inside a DrawerNavigator.',
    )
  }
  return drawer
}

// ─── useParentRouter ──────────────────────────────────────────────────────────

/**
 * Access the parent router when inside a nested navigator.
 * Returns the root router if no parent is available.
 */
export function useParentRouter(): RouterInstance {
  const router = useRouter()
  if (router.parent) return router.parent
  return router
}

// ─── Re-export shared element transition composable ───────────────────────────

export {
  useSharedElementTransition,
  getSharedElementViewId,
  getRegisteredSharedElements,
  clearSharedElementRegistry,
  measureViewFrame,
} from '@thelacanians/vue-native-runtime'

export type {
  SharedElementFrame,
  SharedElementRegistration,
} from '@thelacanians/vue-native-runtime'
