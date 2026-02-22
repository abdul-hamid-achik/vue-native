import { describe, it, expect, beforeEach, vi } from 'vitest'

// console is available at runtime but not declared in ES2020 lib
declare const console: { warn(...args: unknown[]): void }
import { defineComponent } from '@vue/runtime-core'
import { createRouter, resetKeyCounter, type RouteConfig } from '../index'

// Minimal component stubs for testing
const HomeScreen = defineComponent({ name: 'Home', setup: () => () => null })
const SettingsScreen = defineComponent({ name: 'Settings', setup: () => () => null })
const ProfileScreen = defineComponent({ name: 'Profile', setup: () => () => null })

const testRoutes: RouteConfig[] = [
  { name: 'home', component: HomeScreen },
  { name: 'settings', component: SettingsScreen, options: { title: 'Settings' } },
  { name: 'profile', component: ProfileScreen },
]

describe('createRouter', () => {
  beforeEach(() => {
    resetKeyCounter()
  })

  it('throws if no routes provided', () => {
    expect(() => createRouter([])).toThrow('requires at least one route')
  })

  it('initializes with the first route', () => {
    const router = createRouter(testRoutes)
    expect(router.currentRoute.value.config.name).toBe('home')
    expect(router.stack.value).toHaveLength(1)
  })

  it('canGoBack is false initially', () => {
    const router = createRouter(testRoutes)
    expect(router.canGoBack.value).toBe(false)
  })

  describe('navigate / push', () => {
    it('pushes a new route onto the stack', () => {
      const router = createRouter(testRoutes)
      router.navigate('settings')

      expect(router.stack.value).toHaveLength(2)
      expect(router.currentRoute.value.config.name).toBe('settings')
      expect(router.canGoBack.value).toBe(true)
    })

    it('passes params to the route', () => {
      const router = createRouter(testRoutes)
      router.navigate('profile', { userId: '123' })

      expect(router.currentRoute.value.params).toEqual({ userId: '123' })
    })

    it('push is an alias for navigate', () => {
      const router = createRouter(testRoutes)
      router.push('settings')

      expect(router.currentRoute.value.config.name).toBe('settings')
    })

    it('warns on unknown route name', () => {
      const router = createRouter(testRoutes)
      const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {})

      router.navigate('nonexistent')

      expect(warnSpy).toHaveBeenCalledWith(
        expect.stringContaining('Route "nonexistent" not found')
      )
      expect(router.stack.value).toHaveLength(1) // stack unchanged
    })
  })

  describe('goBack / pop', () => {
    it('pops the current route off the stack', () => {
      const router = createRouter(testRoutes)
      router.navigate('settings')
      router.goBack()

      expect(router.stack.value).toHaveLength(1)
      expect(router.currentRoute.value.config.name).toBe('home')
    })

    it('does nothing when at root', () => {
      const router = createRouter(testRoutes)
      router.goBack()

      expect(router.stack.value).toHaveLength(1)
      expect(router.currentRoute.value.config.name).toBe('home')
    })

    it('pop is an alias for goBack', () => {
      const router = createRouter(testRoutes)
      router.push('settings')
      router.pop()

      expect(router.currentRoute.value.config.name).toBe('home')
    })
  })

  describe('replace', () => {
    it('replaces the current route without adding to stack', () => {
      const router = createRouter(testRoutes)
      router.navigate('settings')
      router.replace('profile', { userId: '456' })

      expect(router.stack.value).toHaveLength(2)
      expect(router.currentRoute.value.config.name).toBe('profile')
      expect(router.currentRoute.value.params).toEqual({ userId: '456' })
    })

    it('warns on unknown route', () => {
      const router = createRouter(testRoutes)
      const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {})

      router.replace('unknown')

      expect(warnSpy).toHaveBeenCalled()
    })
  })

  describe('reset', () => {
    it('resets the stack to a single route', () => {
      const router = createRouter(testRoutes)
      router.navigate('settings')
      router.navigate('profile')
      expect(router.stack.value).toHaveLength(3)

      router.reset('home')

      expect(router.stack.value).toHaveLength(1)
      expect(router.currentRoute.value.config.name).toBe('home')
      expect(router.canGoBack.value).toBe(false)
    })

    it('warns on unknown route', () => {
      const router = createRouter(testRoutes)
      const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {})

      router.reset('unknown')

      expect(warnSpy).toHaveBeenCalled()
    })
  })

  describe('unique keys', () => {
    it('assigns unique keys to each route entry', () => {
      const router = createRouter(testRoutes)
      const firstKey = router.currentRoute.value.key

      router.navigate('settings')
      const secondKey = router.currentRoute.value.key

      router.navigate('profile')
      const thirdKey = router.currentRoute.value.key

      expect(firstKey).not.toBe(secondKey)
      expect(secondKey).not.toBe(thirdKey)
    })
  })
})
