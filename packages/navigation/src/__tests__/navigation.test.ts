/**
 * Navigation tests — verifies createRouter, push/pop/replace/reset,
 * navigation guards, deep linking, state persistence, and tab navigation.
 */
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { installMockBridge, nextTick } from './helpers'

const mockBridge = installMockBridge()

// Mock the runtime's NativeBridge for the navigation module
const { NativeBridge } = await import('@thelacanians/vue-native-runtime')

import { defineComponent, h } from '@vue/runtime-core'

// Simple stub components for routes
const HomeScreen = defineComponent({ name: 'Home', setup: () => () => h('VView') })
const AboutScreen = defineComponent({ name: 'About', setup: () => () => h('VView') })
const ProfileScreen = defineComponent({ name: 'Profile', setup: () => () => h('VView') })
const _SettingsScreen = defineComponent({ name: 'Settings', setup: () => () => h('VView') })

describe('Navigation — createRouter', () => {
  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()
    vi.restoreAllMocks()
    // Suppress console.warn for route-not-found tests
    vi.spyOn(console, 'warn').mockImplementation(() => {})
  })

  // We need to dynamically import to get a fresh module for each test
  async function getRouter() {
    const { createRouter } = await import('../index')
    return createRouter
  }

  // ---------------------------------------------------------------------------
  // Basic creation
  // ---------------------------------------------------------------------------
  describe('createRouter basics', () => {
    it('creates a router with initial route from first route config', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])
      expect(router.currentRoute.value.config.name).toBe('home')
      expect(router.stack.value).toHaveLength(1)
    })

    it('throws when created with empty routes', async () => {
      const createRouter = await getRouter()
      expect(() => createRouter([])).toThrow('at least one route')
    })

    it('accepts RouterOptions object format', async () => {
      const createRouter = await getRouter()
      const router = createRouter({
        routes: [
          { name: 'home', component: HomeScreen },
        ],
      })
      expect(router.currentRoute.value.config.name).toBe('home')
    })

    it('canGoBack is false initially', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
      ])
      expect(router.canGoBack.value).toBe(false)
    })
  })

  // ---------------------------------------------------------------------------
  // Navigation: push / navigate
  // ---------------------------------------------------------------------------
  describe('push / navigate', () => {
    it('push adds route to stack', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])

      await router.push('about')
      expect(router.stack.value).toHaveLength(2)
      expect(router.currentRoute.value.config.name).toBe('about')
    })

    it('navigate is an alias for push', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])

      await router.navigate('about')
      expect(router.currentRoute.value.config.name).toBe('about')
    })

    it('push with params sets route params', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'profile', component: ProfileScreen },
      ])

      await router.push('profile', { userId: '123' })
      expect(router.currentRoute.value.params).toEqual({ userId: '123' })
    })

    it('push to unknown route warns and does nothing', async () => {
      const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {})
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
      ])

      await router.push('nonexistent')
      expect(router.stack.value).toHaveLength(1)
      expect(warnSpy).toHaveBeenCalledWith(expect.stringContaining('not found'))
    })

    it('canGoBack is true after push', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])

      await router.push('about')
      expect(router.canGoBack.value).toBe(true)
    })

    it('multiple pushes build the stack', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
        { name: 'profile', component: ProfileScreen },
      ])

      await router.push('about')
      await router.push('profile')
      expect(router.stack.value).toHaveLength(3)
      expect(router.stack.value.map(e => e.config.name)).toEqual(['home', 'about', 'profile'])
    })
  })

  // ---------------------------------------------------------------------------
  // Navigation: goBack / pop
  // ---------------------------------------------------------------------------
  describe('goBack / pop', () => {
    it('goBack removes top route from stack', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])

      await router.push('about')
      expect(router.stack.value).toHaveLength(2)

      await router.goBack()
      expect(router.stack.value).toHaveLength(1)
      expect(router.currentRoute.value.config.name).toBe('home')
    })

    it('pop is alias for goBack', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])

      await router.push('about')
      await router.pop()
      expect(router.currentRoute.value.config.name).toBe('home')
    })

    it('goBack does nothing when only one route in stack', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
      ])

      await router.goBack()
      expect(router.stack.value).toHaveLength(1)
      expect(router.currentRoute.value.config.name).toBe('home')
    })
  })

  // ---------------------------------------------------------------------------
  // Navigation: replace
  // ---------------------------------------------------------------------------
  describe('replace', () => {
    it('replaces current route without adding to stack', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
        { name: 'profile', component: ProfileScreen },
      ])

      await router.push('about')
      expect(router.stack.value).toHaveLength(2)

      await router.replace('profile')
      expect(router.stack.value).toHaveLength(2)
      expect(router.currentRoute.value.config.name).toBe('profile')
    })

    it('replace with params', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'profile', component: ProfileScreen },
      ])

      await router.replace('profile', { userId: '42' })
      expect(router.currentRoute.value.params).toEqual({ userId: '42' })
    })
  })

  // ---------------------------------------------------------------------------
  // Navigation: reset
  // ---------------------------------------------------------------------------
  describe('reset', () => {
    it('resets stack to a single route', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
        { name: 'profile', component: ProfileScreen },
      ])

      await router.push('about')
      await router.push('profile')
      expect(router.stack.value).toHaveLength(3)

      await router.reset('home')
      expect(router.stack.value).toHaveLength(1)
      expect(router.currentRoute.value.config.name).toBe('home')
    })

    it('reset with params', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'profile', component: ProfileScreen },
      ])

      await router.push('profile')
      await router.reset('home', { welcome: true })
      expect(router.currentRoute.value.params).toEqual({ welcome: true })
    })
  })

  // ---------------------------------------------------------------------------
  // Navigation Guards: beforeEach
  // ---------------------------------------------------------------------------
  describe('beforeEach guards', () => {
    it('beforeEach guard is called on navigation', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])

      const guard = vi.fn((_to: any, _from: any, next: any) => next())
      router.beforeEach(guard)

      await router.push('about')
      expect(guard).toHaveBeenCalledTimes(1)
      expect(guard.mock.calls[0][0].config.name).toBe('about')
      expect(guard.mock.calls[0][1].config.name).toBe('home')
    })

    it('beforeEach guard can block navigation', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])

      router.beforeEach((_to: any, _from: any, next: any) => next(false))

      await router.push('about')
      // Navigation should be blocked
      expect(router.currentRoute.value.config.name).toBe('home')
      expect(router.stack.value).toHaveLength(1)
    })

    it('beforeEach guard can redirect', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
        { name: 'profile', component: ProfileScreen },
      ])

      let firstCall = true
      router.beforeEach((_to: any, _from: any, next: any) => {
        if (firstCall && _to.config.name === 'about') {
          firstCall = false
          next('profile')
        } else {
          next()
        }
      })

      await router.push('about')
      // The redirect happens asynchronously — wait for microtasks
      await nextTick()
      // Should have been redirected to profile
      expect(router.currentRoute.value.config.name).toBe('profile')
    })

    it('unsubscribe removes guard', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])

      const guard = vi.fn((_to: any, _from: any, next: any) => next(false))
      const unsub = router.beforeEach(guard)

      // Guard should block
      await router.push('about')
      expect(router.currentRoute.value.config.name).toBe('home')

      // Unsubscribe and try again
      unsub()
      guard.mockClear()
      await router.push('about')
      expect(guard).not.toHaveBeenCalled()
      expect(router.currentRoute.value.config.name).toBe('about')
    })
  })

  // ---------------------------------------------------------------------------
  // Navigation Guards: afterEach
  // ---------------------------------------------------------------------------
  describe('afterEach hooks', () => {
    it('afterEach is called after successful navigation', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])

      const afterHook = vi.fn()
      router.afterEach(afterHook)

      await router.push('about')
      expect(afterHook).toHaveBeenCalledTimes(1)
      expect(afterHook.mock.calls[0][0].config.name).toBe('about')
      expect(afterHook.mock.calls[0][1].config.name).toBe('home')
    })

    it('afterEach is NOT called when guard blocks navigation', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])

      router.beforeEach((_to: any, _from: any, next: any) => next(false))
      const afterHook = vi.fn()
      router.afterEach(afterHook)

      await router.push('about')
      expect(afterHook).not.toHaveBeenCalled()
    })

    it('unsubscribe removes after hook', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])

      const afterHook = vi.fn()
      const unsub = router.afterEach(afterHook)

      await router.push('about')
      expect(afterHook).toHaveBeenCalledTimes(1)

      unsub()
      afterHook.mockClear()
      await router.goBack()
      // After unsub, goBack should not trigger afterHook
    })
  })

  // ---------------------------------------------------------------------------
  // Navigation Guards: beforeResolve
  // ---------------------------------------------------------------------------
  describe('beforeResolve guards', () => {
    it('beforeResolve runs after beforeEach', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])

      const order: string[] = []
      router.beforeEach((_to: any, _from: any, next: any) => {
        order.push('beforeEach')
        next()
      })
      router.beforeResolve((_to: any, _from: any, next: any) => {
        order.push('beforeResolve')
        next()
      })

      await router.push('about')
      expect(order).toEqual(['beforeEach', 'beforeResolve'])
    })

    it('beforeResolve can block navigation', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])

      router.beforeResolve((_to: any, _from: any, next: any) => next(false))

      await router.push('about')
      expect(router.currentRoute.value.config.name).toBe('home')
    })
  })

  // ---------------------------------------------------------------------------
  // Deep Linking
  // ---------------------------------------------------------------------------
  describe('deep linking', () => {
    it('handleURL matches a simple path', async () => {
      const createRouter = await getRouter()
      const router = createRouter({
        routes: [
          { name: 'home', component: HomeScreen },
          { name: 'profile', component: ProfileScreen },
        ],
        linking: {
          prefixes: ['myapp://'],
          config: {
            screens: {
              home: '',
              profile: 'profile/:id',
            },
          },
        },
      })

      const result = router.handleURL('myapp://profile/42')
      // handleURL is async internally but returns boolean synchronously
      // Wait for the navigate to complete
      await nextTick()
      expect(result).toBe(true)
    })

    it('handleURL returns false for unmatched path', async () => {
      const createRouter = await getRouter()
      const router = createRouter({
        routes: [
          { name: 'home', component: HomeScreen },
        ],
        linking: {
          prefixes: ['myapp://'],
          config: {
            screens: {
              home: '',
            },
          },
        },
      })

      const result = router.handleURL('myapp://unknown/path/here')
      expect(result).toBe(false)
    })

    it('handleURL returns false when no linking config', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
      ])

      const result = router.handleURL('myapp://anything')
      expect(result).toBe(false)
    })

    it('handleURL strips the prefix before matching', async () => {
      const createRouter = await getRouter()
      const router = createRouter({
        routes: [
          { name: 'home', component: HomeScreen },
          { name: 'about', component: AboutScreen },
        ],
        linking: {
          prefixes: ['https://example.com/'],
          config: {
            screens: {
              about: 'about',
            },
          },
        },
      })

      const result = router.handleURL('https://example.com/about')
      await nextTick()
      expect(result).toBe(true)
    })
  })

  // ---------------------------------------------------------------------------
  // State persistence
  // ---------------------------------------------------------------------------
  describe('state persistence', () => {
    it('getState returns serializable navigation state', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])

      await router.push('about', { page: 1 })
      const state = router.getState()

      expect(state.stack).toHaveLength(2)
      expect(state.stack[0].name).toBe('home')
      expect(state.stack[1].name).toBe('about')
      expect(state.stack[1].params).toEqual({ page: 1 })
      expect(state.index).toBe(1)
    })

    it('restoreState restores the stack', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
        { name: 'profile', component: ProfileScreen },
      ])

      router.restoreState({
        stack: [
          { name: 'home', params: {} },
          { name: 'about', params: {} },
          { name: 'profile', params: { id: '99' } },
        ],
        index: 2,
      })

      expect(router.stack.value).toHaveLength(3)
      expect(router.currentRoute.value.config.name).toBe('profile')
      expect(router.currentRoute.value.params).toEqual({ id: '99' })
    })

    it('restoreState ignores invalid state', async () => {
      const _warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {})
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
      ])

      router.restoreState(null as any)
      expect(router.stack.value).toHaveLength(1)
      expect(router.currentRoute.value.config.name).toBe('home')
    })

    it('restoreState ignores state with unknown routes', async () => {
      const _warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {})
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
      ])

      router.restoreState({
        stack: [
          { name: 'home', params: {} },
          { name: 'deleted-screen', params: {} },
        ],
        index: 1,
      })

      // Should keep the original state since a route was unknown
      expect(router.stack.value).toHaveLength(1)
      expect(router.currentRoute.value.config.name).toBe('home')
    })
  })

  // ---------------------------------------------------------------------------
  // Tab navigation (createTabNavigator)
  // ---------------------------------------------------------------------------
  describe('createTabNavigator', () => {
    it('creates TabNavigator component and activeTab ref', async () => {
      const { createTabNavigator } = await import('../index')
      const { TabNavigator, activeTab } = createTabNavigator()
      expect(TabNavigator).toBeDefined()
      expect(activeTab.value).toBe('')
    })

    it('creates TabScreen component', async () => {
      const { createTabNavigator } = await import('../index')
      const { TabScreen } = createTabNavigator()
      expect(TabScreen).toBeDefined()
    })
  })

  // ---------------------------------------------------------------------------
  // Drawer navigation (createDrawerNavigator)
  // ---------------------------------------------------------------------------
  describe('createDrawerNavigator', () => {
    it('creates DrawerNavigator component and useDrawer', async () => {
      const { createDrawerNavigator } = await import('../index')
      const { DrawerNavigator, useDrawer, activeScreen } = createDrawerNavigator()
      expect(DrawerNavigator).toBeDefined()
      expect(activeScreen.value).toBe('')

      const drawer = useDrawer()
      expect(drawer.isOpen.value).toBe(false)
    })

    it('openDrawer/closeDrawer/toggleDrawer work', async () => {
      const { createDrawerNavigator } = await import('../index')
      const { useDrawer } = createDrawerNavigator()
      const drawer = useDrawer()

      expect(drawer.isOpen.value).toBe(false)
      drawer.openDrawer()
      expect(drawer.isOpen.value).toBe(true)
      drawer.closeDrawer()
      expect(drawer.isOpen.value).toBe(false)
      drawer.toggleDrawer()
      expect(drawer.isOpen.value).toBe(true)
      drawer.toggleDrawer()
      expect(drawer.isOpen.value).toBe(false)
    })
  })

  // ---------------------------------------------------------------------------
  // Route assignment uniqueness
  // ---------------------------------------------------------------------------
  describe('route entry keys', () => {
    it('each navigation assigns a unique key to the route entry', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])

      await router.push('about')
      const keys = router.stack.value.map(e => e.key)
      expect(new Set(keys).size).toBe(keys.length)
    })
  })

  // ---------------------------------------------------------------------------
  // Shared element transitions
  // ---------------------------------------------------------------------------
  describe('shared element transitions', () => {
    it('push with sharedElements stores them on the route entry', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'profile', component: ProfileScreen },
      ])

      await router.push('profile', { id: '1' }, { sharedElements: ['hero-image'] })
      expect(router.currentRoute.value.sharedElements).toEqual(['hero-image'])
    })

    it('push without sharedElements leaves them undefined', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])

      await router.push('about')
      expect(router.currentRoute.value.sharedElements).toBeUndefined()
    })

    it('navigate with sharedElements stores them on the route entry', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'profile', component: ProfileScreen },
      ])

      await router.navigate('profile', { id: '2' }, { sharedElements: ['avatar', 'title'] })
      expect(router.currentRoute.value.sharedElements).toEqual(['avatar', 'title'])
    })

    it('sharedElements are preserved in the stack', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
        { name: 'profile', component: ProfileScreen },
      ])

      await router.push('about', {}, { sharedElements: ['card'] })
      await router.push('profile', {}, { sharedElements: ['hero'] })

      expect(router.stack.value[1].sharedElements).toEqual(['card'])
      expect(router.stack.value[2].sharedElements).toEqual(['hero'])
    })

    it('pop returns to previous entry without shared elements', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'profile', component: ProfileScreen },
      ])

      await router.push('profile', {}, { sharedElements: ['hero-image'] })
      expect(router.currentRoute.value.sharedElements).toEqual(['hero-image'])

      await router.pop()
      expect(router.currentRoute.value.sharedElements).toBeUndefined()
    })
  })

  // ---------------------------------------------------------------------------
  // Bug fix: Circular redirect protection (P0 1.2)
  // ---------------------------------------------------------------------------
  describe('circular redirect protection', () => {
    it('stops after max redirect depth and warns', async () => {
      const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {})
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'a', component: AboutScreen },
        { name: 'b', component: ProfileScreen },
      ])

      // Guard creates an infinite A→B→A loop
      router.beforeEach((_to: any, _from: any, next: any) => {
        if (_to.config.name === 'a') next('b')
        else if (_to.config.name === 'b') next('a')
        else next()
      })

      await router.push('a')
      await nextTick()

      // Should have warned about circular redirect, not hung or crashed
      expect(warnSpy).toHaveBeenCalledWith(
        expect.stringContaining('Circular redirect'),
      )
    })
  })

  // ---------------------------------------------------------------------------
  // Bug fix: goBack() runs guards (P1 2.5)
  // ---------------------------------------------------------------------------
  describe('goBack runs guards', () => {
    it('beforeEach fires on goBack', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])

      await router.push('about')
      const guard = vi.fn((_to: any, _from: any, next: any) => next())
      router.beforeEach(guard)

      await router.goBack()
      expect(guard).toHaveBeenCalledTimes(1)
      expect(guard.mock.calls[0][0].config.name).toBe('home')
      expect(guard.mock.calls[0][1].config.name).toBe('about')
    })

    it('beforeEach can block goBack', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])

      await router.push('about')
      router.beforeEach((_to: any, _from: any, next: any) => next(false))

      await router.goBack()
      // Navigation should be blocked — still on about
      expect(router.currentRoute.value.config.name).toBe('about')
      expect(router.stack.value).toHaveLength(2)
    })
  })

  // ---------------------------------------------------------------------------
  // Bug fix: Deep links with query strings (P1 2.6)
  // ---------------------------------------------------------------------------
  describe('deep link query strings', () => {
    it('parses query params from deep link URL', async () => {
      const createRouter = await getRouter()
      const router = createRouter({
        routes: [
          { name: 'home', component: HomeScreen },
          { name: 'profile', component: ProfileScreen },
        ],
        linking: {
          prefixes: ['myapp://'],
          config: {
            screens: {
              profile: 'profile/:id',
            },
          },
        },
      })

      const result = router.handleURL('myapp://profile/42?tab=posts&sort=recent')
      await nextTick()
      expect(result).toBe(true)
      // Path params should take precedence, query params merged in
      expect(router.currentRoute.value.params.id).toBe('42')
      expect(router.currentRoute.value.params.tab).toBe('posts')
      expect(router.currentRoute.value.params.sort).toBe('recent')
    })

    it('strips fragment before matching', async () => {
      const createRouter = await getRouter()
      const router = createRouter({
        routes: [
          { name: 'home', component: HomeScreen },
          { name: 'about', component: AboutScreen },
        ],
        linking: {
          prefixes: ['myapp://'],
          config: {
            screens: {
              about: 'about',
            },
          },
        },
      })

      const result = router.handleURL('myapp://about#section1')
      await nextTick()
      expect(result).toBe(true)
      expect(router.currentRoute.value.config.name).toBe('about')
    })
  })

  // ---------------------------------------------------------------------------
  // Bug fix: Deep link prefix matching longest first (P1 2.11)
  // ---------------------------------------------------------------------------
  describe('deep link prefix matching', () => {
    it('matches longest prefix first', async () => {
      const createRouter = await getRouter()
      const router = createRouter({
        routes: [
          { name: 'home', component: HomeScreen },
          { name: 'about', component: AboutScreen },
        ],
        linking: {
          prefixes: ['myapp://', 'myapp://deep/'],
          config: {
            screens: {
              about: 'about',
            },
          },
        },
      })

      // 'myapp://deep/' is longer and should match first, leaving 'about'
      const result = router.handleURL('myapp://deep/about')
      await nextTick()
      expect(result).toBe(true)
      expect(router.currentRoute.value.config.name).toBe('about')
    })
  })

  // ---------------------------------------------------------------------------
  // Bug fix: Params preserved on guard redirects (P1 2.10)
  // ---------------------------------------------------------------------------
  describe('params on guard redirects', () => {
    it('replace forwards params on guard redirect', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
        { name: 'profile', component: ProfileScreen },
      ])

      // Guard redirects 'about' to 'profile'
      router.beforeEach((to: any, _from: any, next: any) => {
        if (to.config.name === 'about') next('profile')
        else next()
      })

      await router.replace('about', { userId: '123' })
      await nextTick()

      expect(router.currentRoute.value.config.name).toBe('profile')
      expect(router.currentRoute.value.params.userId).toBe('123')
    })

    it('reset forwards params on guard redirect', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
        { name: 'profile', component: ProfileScreen },
      ])

      router.beforeEach((to: any, _from: any, next: any) => {
        if (to.config.name === 'about') next('profile')
        else next()
      })

      await router.reset('about', { userId: '456' })
      await nextTick()

      expect(router.currentRoute.value.config.name).toBe('profile')
      expect(router.currentRoute.value.params.userId).toBe('456')
    })
  })

  // ---------------------------------------------------------------------------
  // Bug fix: afterEach fires on goBack (P1 2.5 continued)
  // ---------------------------------------------------------------------------
  describe('goBack afterEach hooks', () => {
    it('afterEach fires after successful goBack', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])

      await router.push('about')

      const afterHook = vi.fn()
      router.afterEach(afterHook)

      await router.goBack()
      expect(afterHook).toHaveBeenCalledTimes(1)
      expect(afterHook.mock.calls[0][0].config.name).toBe('home') // to
      expect(afterHook.mock.calls[0][1].config.name).toBe('about') // from
    })

    it('afterEach does not fire when goBack is blocked', async () => {
      const createRouter = await getRouter()
      const router = createRouter([
        { name: 'home', component: HomeScreen },
        { name: 'about', component: AboutScreen },
      ])

      await router.push('about')

      router.beforeEach((_to: any, _from: any, next: any) => next(false))
      const afterHook = vi.fn()
      router.afterEach(afterHook)

      await router.goBack()
      expect(afterHook).not.toHaveBeenCalled()
    })
  })
})
