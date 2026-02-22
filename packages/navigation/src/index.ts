import {
  ref,
  shallowRef,
  computed,
  defineComponent,
  h,
  provide,
  inject,
  type Component,
  type InjectionKey,
  type ComputedRef,
  type Ref,
  type ShallowRef,
} from '@vue/runtime-core'

// console exists at runtime in JavaScriptCore (polyfilled) but is not in ES2020 lib
declare const console: { warn(...args: unknown[]): void }

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

export interface RouteEntry {
  config: RouteConfig
  params: Record<string, unknown>
  key: number
}

export interface RouteLocation {
  name: string
  params: Record<string, unknown>
  options: RouteOptions
}

export interface RouterInstance {
  /** The currently visible route entry (shallowRef). */
  currentRoute: ShallowRef<RouteEntry>
  /** Full navigation stack (ref). */
  stack: Ref<RouteEntry[]>
  /** Push a new route onto the stack. */
  navigate(name: string, params?: Record<string, unknown>): void
  /** Alias for navigate — preferred name in new API. */
  push(name: string, params?: Record<string, unknown>): void
  /** Pop the current route off the stack. */
  goBack(): void
  /** Alias for goBack — preferred name in new API. */
  pop(): void
  /** Replace the current route without adding to the stack. */
  replace(name: string, params?: Record<string, unknown>): void
  /** Reset the stack to a single route. */
  reset(name: string, params?: Record<string, unknown>): void
  /** Whether there is a previous route to go back to. */
  canGoBack: ComputedRef<boolean>
  /** Install into a Vue app (app.use(router)). */
  install(app: any): void
}

export interface TabBarItem {
  name: string
  label?: string
  icon?: string
}

// ─── Injection Keys ───────────────────────────────────────────────────────────

const ROUTER_KEY: InjectionKey<RouterInstance> = Symbol('router')
const ROUTE_KEY: InjectionKey<ComputedRef<RouteLocation>> = Symbol('route')

// ─── createRouter ─────────────────────────────────────────────────────────────

let keyCounter = 0

/**
 * Reset the key counter. Used for testing purposes only.
 */
export function resetKeyCounter(): void {
  keyCounter = 0
}

export function createRouter(routes: RouteConfig[]): RouterInstance {
  if (routes.length === 0) {
    throw new Error('[vue-native/navigation] createRouter requires at least one route')
  }

  const routeMap = new Map(routes.map(r => [r.name, r]))

  const initialEntry: RouteEntry = { config: routes[0], params: {}, key: keyCounter++ }
  const stack = ref<RouteEntry[]>([initialEntry])
  const currentRoute = shallowRef<RouteEntry>(initialEntry)

  const canGoBack: ComputedRef<boolean> = computed(() => stack.value.length > 1)

  function navigate(name: string, params: Record<string, unknown> = {}): void {
    const config = routeMap.get(name)
    if (!config) {
      console.warn(`[vue-native/navigation] Route "${name}" not found`)
      return
    }
    const entry: RouteEntry = { config, params, key: keyCounter++ }
    stack.value = [...stack.value, entry]
    currentRoute.value = entry
  }

  function goBack(): void {
    if (stack.value.length <= 1) return
    const newStack = stack.value.slice(0, -1)
    stack.value = newStack
    currentRoute.value = newStack[newStack.length - 1]
  }

  function replace(name: string, params: Record<string, unknown> = {}): void {
    const config = routeMap.get(name)
    if (!config) {
      console.warn(`[vue-native/navigation] Route "${name}" not found`)
      return
    }
    const entry: RouteEntry = { config, params, key: keyCounter++ }
    stack.value = [...stack.value.slice(0, -1), entry]
    currentRoute.value = entry
  }

  function reset(name: string, params: Record<string, unknown> = {}): void {
    const config = routeMap.get(name)
    if (!config) {
      console.warn(`[vue-native/navigation] Route "${name}" not found`)
      return
    }
    const entry: RouteEntry = { config, params, key: keyCounter++ }
    stack.value = [entry]
    currentRoute.value = entry
  }

  const router: RouterInstance = {
    currentRoute,
    stack,
    canGoBack,
    navigate,
    push: navigate,
    goBack,
    pop: goBack,
    replace,
    reset,
    install(app: any) {
      app.provide(ROUTER_KEY, router)
    },
  }

  return router
}

// ─── useRouter / useRoute ─────────────────────────────────────────────────────

export function useRouter(): RouterInstance {
  const router = inject(ROUTER_KEY)
  if (!router) {
    throw new Error(
      '[vue-native/navigation] useRouter() called outside of router context. ' +
      'Make sure app.use(router) is called.'
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
    provide(ROUTE_KEY, routeLocation)
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
      return h(
        'VView',
        {
          style: {
            flex: 1,
            overflow: 'hidden',
            position: 'relative',
          },
        },
        entries.map((entry, index) => {
          const isTop = index === entries.length - 1
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
                h(entry.config.component as any, { routeParams: entry.params })
              ),
            ]
          )
        })
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
                    () => `\u2039 ${props.backTitle}`
                  )
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
              () => props.title
            ),
          ]),

          // ── Right slot: spacer to balance left side ───────────────────────
          h('VView', { style: { minWidth: 60 } }),
        ]
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
        props.tabs.map(tab => {
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
                    () => tab.icon as string
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
                () => tab.label ?? tab.name
              ),
            ]
          )
        })
      )
  },
})

// ─── createTabNavigator ───────────────────────────────────────────────────────

export interface TabScreenConfig {
  name: string
  label?: string
  icon?: string
  component: Component
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

        const currentScreen = screens.find(s => s.name === activeTab.value) ?? screens[0]

        const tabs: TabBarItem[] = screens.map(s => ({
          name: s.name,
          label: s.label,
          icon: s.icon,
        }))

        return h('VView', { style: { flex: 1 } }, [
          // ── Screen area ─────────────────────────────────────────────────
          h('VView', { style: { flex: 1 } }, [
            h(currentScreen.component as any),
          ]),
          // ── Tab bar ──────────────────────────────────────────────────────
          h(VTabBar, {
            tabs,
            modelValue: activeTab.value,
            activeColor: props.activeColor,
            inactiveColor: props.inactiveColor,
            backgroundColor: props.tabBarBackgroundColor,
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
    },
    setup() {
      // Intentionally renders nothing — used as a declarative config child.
      return () => null
    },
  })

  return { TabNavigator, TabScreen, activeTab }
}
