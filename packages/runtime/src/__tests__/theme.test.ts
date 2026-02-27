/**
 * Theme system tests — verifies createTheme, useTheme, ThemeProvider,
 * createDynamicStyleSheet, and toggleColorScheme.
 */
import { describe, it, expect, beforeEach } from 'vitest'
import { installMockBridge } from './helpers'

const mockBridge = installMockBridge()

const { NativeBridge } = await import('../bridge')
const { resetNodeId, createNativeNode } = await import('../node')
const { baseCreateApp } = await import('../renderer')

import {
  defineComponent, h, ref,
  type ComputedRef,
} from '@vue/runtime-core'

const { createTheme, createDynamicStyleSheet } = await import('../theme')

// ─── Theme definition ─────────────────────────────────────────────────────

const lightTheme = {
  colors: { background: '#FFFFFF', text: '#1A1A1A', primary: '#007AFF' },
  spacing: { sm: 8, md: 16, lg: 24 },
}

const darkTheme = {
  colors: { background: '#1A1A1A', text: '#F5F5F5', primary: '#0A84FF' },
  spacing: { sm: 8, md: 16, lg: 24 },
}

describe('Theme System', () => {
  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()
    resetNodeId()
  })

  // ─────────────────────────────────────────────────────────────────────────
  // createTheme
  // ─────────────────────────────────────────────────────────────────────────
  describe('createTheme', () => {
    it('returns ThemeProvider component and useTheme function', () => {
      const result = createTheme({ light: lightTheme, dark: darkTheme })
      expect(result.ThemeProvider).toBeDefined()
      expect(typeof result.useTheme).toBe('function')
    })

    it('ThemeProvider has correct component name', () => {
      const { ThemeProvider } = createTheme({ light: lightTheme, dark: darkTheme })
      expect(ThemeProvider.name).toBe('ThemeProvider')
    })
  })

  // ─────────────────────────────────────────────────────────────────────────
  // useTheme inside ThemeProvider
  // ─────────────────────────────────────────────────────────────────────────
  describe('useTheme', () => {
    it('returns theme context with light scheme by default', () => {
      const { ThemeProvider, useTheme } = createTheme({ light: lightTheme, dark: darkTheme })

      let captured: any
      const Child = defineComponent({
        setup() {
          captured = useTheme()
          return () => h('VView')
        },
      })

      const App = defineComponent({
        setup() {
          return () => h(ThemeProvider, null, { default: () => h(Child) })
        },
      })

      const root = createNativeNode('__ROOT__')
      const app = baseCreateApp(App)
      app.mount(root as any)

      expect(captured).toBeDefined()
      expect(captured.colorScheme.value).toBe('light')
      expect(captured.theme.value).toEqual(lightTheme)
    })

    it('throws when called outside ThemeProvider', () => {
      const { useTheme } = createTheme({ light: lightTheme, dark: darkTheme })

      let error: Error | undefined
      const App = defineComponent({
        setup() {
          try {
            useTheme()
          } catch (e) {
            error = e as Error
          }
          return () => h('VView')
        },
      })

      const root = createNativeNode('__ROOT__')
      const app = baseCreateApp(App)
      app.mount(root as any)

      expect(error).toBeDefined()
      expect(error!.message).toContain('useTheme()')
      expect(error!.message).toContain('ThemeProvider')
    })

    it('respects initialColorScheme prop', () => {
      const { ThemeProvider, useTheme } = createTheme({ light: lightTheme, dark: darkTheme })

      let captured: any
      const Child = defineComponent({
        setup() {
          captured = useTheme()
          return () => h('VView')
        },
      })

      const App = defineComponent({
        setup() {
          return () => h(ThemeProvider, { initialColorScheme: 'dark' }, { default: () => h(Child) })
        },
      })

      const root = createNativeNode('__ROOT__')
      const app = baseCreateApp(App)
      app.mount(root as any)

      expect(captured.colorScheme.value).toBe('dark')
      expect(captured.theme.value).toEqual(darkTheme)
    })
  })

  // ─────────────────────────────────────────────────────────────────────────
  // toggleColorScheme
  // ─────────────────────────────────────────────────────────────────────────
  describe('toggleColorScheme', () => {
    it('toggles between light and dark', () => {
      const { ThemeProvider, useTheme } = createTheme({ light: lightTheme, dark: darkTheme })

      let captured: any
      const Child = defineComponent({
        setup() {
          captured = useTheme()
          return () => h('VView')
        },
      })

      const App = defineComponent({
        setup() {
          return () => h(ThemeProvider, null, { default: () => h(Child) })
        },
      })

      const root = createNativeNode('__ROOT__')
      const app = baseCreateApp(App)
      app.mount(root as any)

      expect(captured.colorScheme.value).toBe('light')
      captured.toggleColorScheme()
      expect(captured.colorScheme.value).toBe('dark')
      expect(captured.theme.value).toEqual(darkTheme)
      captured.toggleColorScheme()
      expect(captured.colorScheme.value).toBe('light')
      expect(captured.theme.value).toEqual(lightTheme)
    })
  })

  // ─────────────────────────────────────────────────────────────────────────
  // setColorScheme
  // ─────────────────────────────────────────────────────────────────────────
  describe('setColorScheme', () => {
    it('sets a specific color scheme', () => {
      const { ThemeProvider, useTheme } = createTheme({ light: lightTheme, dark: darkTheme })

      let captured: any
      const Child = defineComponent({
        setup() {
          captured = useTheme()
          return () => h('VView')
        },
      })

      const App = defineComponent({
        setup() {
          return () => h(ThemeProvider, null, { default: () => h(Child) })
        },
      })

      const root = createNativeNode('__ROOT__')
      const app = baseCreateApp(App)
      app.mount(root as any)

      captured.setColorScheme('dark')
      expect(captured.colorScheme.value).toBe('dark')
      expect(captured.theme.value).toEqual(darkTheme)

      captured.setColorScheme('light')
      expect(captured.colorScheme.value).toBe('light')
      expect(captured.theme.value).toEqual(lightTheme)
    })
  })

  // ─────────────────────────────────────────────────────────────────────────
  // ThemeProvider renders children
  // ─────────────────────────────────────────────────────────────────────────
  describe('ThemeProvider rendering', () => {
    it('renders slot children', async () => {
      const { ThemeProvider } = createTheme({ light: lightTheme, dark: darkTheme })

      const App = defineComponent({
        setup() {
          return () => h(ThemeProvider, null, {
            default: () => h('VText', null, 'Hello themed!'),
          })
        },
      })

      const root = createNativeNode('__ROOT__')
      NativeBridge.createNode(root.id, '__ROOT__')
      const app = baseCreateApp(App)
      app.mount(root as any)

      // Wait for rendering
      await new Promise(resolve => setTimeout(resolve, 0))

      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VText')).toBe(true)
    })
  })

  // ─────────────────────────────────────────────────────────────────────────
  // Theme changes propagate to nested components
  // ─────────────────────────────────────────────────────────────────────────
  describe('theme propagation', () => {
    it('nested components see the same theme context', () => {
      const { ThemeProvider, useTheme } = createTheme({ light: lightTheme, dark: darkTheme })

      let parentCtx: any
      let childCtx: any

      const GrandChild = defineComponent({
        setup() {
          childCtx = useTheme()
          return () => h('VView')
        },
      })

      const Child = defineComponent({
        setup() {
          parentCtx = useTheme()
          return () => h(GrandChild)
        },
      })

      const App = defineComponent({
        setup() {
          return () => h(ThemeProvider, null, { default: () => h(Child) })
        },
      })

      const root = createNativeNode('__ROOT__')
      const app = baseCreateApp(App)
      app.mount(root as any)

      // Both should share the same context
      expect(parentCtx.colorScheme.value).toBe('light')
      expect(childCtx.colorScheme.value).toBe('light')

      // Toggling from parent should affect child
      parentCtx.toggleColorScheme()
      expect(childCtx.colorScheme.value).toBe('dark')
      expect(childCtx.theme.value).toEqual(darkTheme)
    })
  })

  // ─────────────────────────────────────────────────────────────────────────
  // createDynamicStyleSheet
  // ─────────────────────────────────────────────────────────────────────────
  describe('createDynamicStyleSheet', () => {
    it('returns a computed stylesheet based on theme', () => {
      const { ThemeProvider, useTheme } = createTheme({ light: lightTheme, dark: darkTheme })

      let styles: ComputedRef<any>
      let ctx: any

      const Child = defineComponent({
        setup() {
          ctx = useTheme()
          styles = createDynamicStyleSheet(ctx.theme, t => ({
            container: { backgroundColor: t.colors.background, padding: t.spacing.md },
            title: { color: t.colors.text },
          }))
          return () => h('VView')
        },
      })

      const App = defineComponent({
        setup() {
          return () => h(ThemeProvider, null, { default: () => h(Child) })
        },
      })

      const root = createNativeNode('__ROOT__')
      const app = baseCreateApp(App)
      app.mount(root as any)

      expect(styles!.value.container.backgroundColor).toBe('#FFFFFF')
      expect(styles!.value.container.padding).toBe(16)
      expect(styles!.value.title.color).toBe('#1A1A1A')
    })

    it('recomputes when theme changes', () => {
      const { ThemeProvider, useTheme } = createTheme({ light: lightTheme, dark: darkTheme })

      let styles: ComputedRef<any>
      let ctx: any

      const Child = defineComponent({
        setup() {
          ctx = useTheme()
          styles = createDynamicStyleSheet(ctx.theme, t => ({
            container: { backgroundColor: t.colors.background },
          }))
          return () => h('VView')
        },
      })

      const App = defineComponent({
        setup() {
          return () => h(ThemeProvider, null, { default: () => h(Child) })
        },
      })

      const root = createNativeNode('__ROOT__')
      const app = baseCreateApp(App)
      app.mount(root as any)

      expect(styles!.value.container.backgroundColor).toBe('#FFFFFF')

      ctx.toggleColorScheme()
      expect(styles!.value.container.backgroundColor).toBe('#1A1A1A')
    })

    it('works with a plain ref theme', () => {
      // createDynamicStyleSheet also accepts Ref<T>
      const theme = ref(lightTheme)
      const styles = createDynamicStyleSheet(theme as any, t => ({
        box: { padding: t.spacing.sm },
      }))

      expect(styles.value.box.padding).toBe(8)
    })

    it('returns frozen style objects', () => {
      const theme = ref(lightTheme)
      const styles = createDynamicStyleSheet(theme as any, t => ({
        box: { padding: t.spacing.sm },
      }))

      expect(Object.isFrozen(styles.value.box)).toBe(true)
    })
  })
})
