# Testing

Vue Native apps run on a custom renderer backed by a native bridge -- there is no DOM. This guide explains how to unit test your components and composables using Vitest by mocking the bridge layer.

## Setup

Install Vitest and the Vue test utilities:

```bash
bun add -d vitest @vue/test-utils
```

### Vitest Configuration

Create or update `vitest.config.ts` in your project root:

```ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'node',
    globals: true,
  },
  resolve: {
    alias: {
      '@': './src',
    },
  },
})
```

::: tip
Use `environment: 'node'` -- not `jsdom`. Vue Native renders to a native bridge, not the DOM, so a browser-like environment is unnecessary and adds overhead.
:::

## Mocking the Native Bridge

Every test file that exercises Vue Native components or composables must mock the bridge before anything else runs. The bridge communicates with native code through a global `__VN_flushOperations` function. In tests, you replace it with a spy that captures operations.

```ts
// test/helpers.ts
import { vi } from 'vitest'

export function installMockBridge() {
  const ops: Array<{ op: string; args: any[] }> = []

  ;(globalThis as any).__VN_flushOperations = (json: string) => {
    ops.push(...JSON.parse(json))
  }
  ;(globalThis as any).__VN_handleEvent = vi.fn()
  ;(globalThis as any).__VN_resolveCallback = vi.fn()
  ;(globalThis as any).__VN_handleGlobalEvent = vi.fn()
  ;(globalThis as any).__DEV__ = true

  return {
    getOps: () => [...ops],
    getOpsByType: (type: string) => ops.filter(o => o.op === type),
    reset: () => { ops.length = 0 },
  }
}

export async function nextTick() {
  await Promise.resolve()
  await Promise.resolve()
  await new Promise(resolve => setTimeout(resolve, 0))
}
```

Install the mock bridge **at module scope** so it runs before any `import` of the runtime:

```ts
import { installMockBridge, nextTick } from './helpers'

const mockBridge = installMockBridge()
const { NativeBridge } = await import('@thelacanians/vue-native-runtime')
```

::: warning
The mock must be installed before importing `NativeBridge`. Use top-level `await import()` to guarantee ordering.
:::

## Testing Components

Components produce bridge operations (create, updateProp, addEventListener, etc.) instead of DOM nodes. Assert on those operations.

```ts
import { describe, it, expect, beforeEach } from 'vitest'
import { createVNode } from '@vue/runtime-core'
import { installMockBridge, nextTick } from './helpers'

const mockBridge = installMockBridge()

const { NativeBridge } = await import('@thelacanians/vue-native-runtime')
const { render, createNativeNode, VView, VText, VButton } =
  await import('@thelacanians/vue-native-runtime')

function renderComponent(vnode: any) {
  const root = createNativeNode('__ROOT__')
  NativeBridge.createNode(root.id, '__ROOT__')
  render(vnode, root)
  return root
}

describe('MyCounter', () => {
  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()
  })

  it('creates a VView and a VText', async () => {
    renderComponent(createVNode(VView, null, {
      default: () => [createVNode(VText, null, { default: () => 'Count: 0' })],
    }))
    await nextTick()

    const creates = mockBridge.getOpsByType('create')
    const types = creates.map(o => o.args[1])
    expect(types).toContain('VView')
    expect(types).toContain('VText')
  })

  it('registers a press handler on VButton', async () => {
    const handler = vi.fn()
    renderComponent(createVNode(VButton, { onPress: handler }))
    await nextTick()

    const events = mockBridge.getOpsByType('addEventListener')
    expect(events.some(o => o.args[1] === 'press')).toBe(true)
  })

  it('forwards style props', async () => {
    renderComponent(createVNode(VView, { style: { flex: 1, padding: 20 } }))
    await nextTick()

    const styles = mockBridge.getOpsByType('updateStyle')
    expect(styles.find(o => o.args[1].flex === 1)).toBeDefined()
  })
})
```

## Testing Composables

Composables call `NativeBridge.invokeNativeModule(module, method, args)` under the hood. Spy on that method to verify calls without needing a native runtime.

```ts
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { installMockBridge } from './helpers'

const mockBridge = installMockBridge()
const { NativeBridge } = await import('@thelacanians/vue-native-runtime')

describe('useAsyncStorage', () => {
  let invokeModuleSpy: ReturnType<typeof vi.spyOn>

  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()
    invokeModuleSpy = vi.spyOn(NativeBridge, 'invokeNativeModule')
      .mockResolvedValue(undefined as any)
  })

  afterEach(() => vi.restoreAllMocks())

  it('setItem calls AsyncStorage.setItem', async () => {
    const { useAsyncStorage } = await import('@thelacanians/vue-native-runtime')
    const { setItem } = useAsyncStorage()

    await setItem('token', 'abc123')

    expect(invokeModuleSpy).toHaveBeenCalledWith(
      'AsyncStorage', 'setItem', ['token', 'abc123']
    )
  })

  it('getItem returns the stored value', async () => {
    invokeModuleSpy.mockResolvedValueOnce('abc123')

    const { useAsyncStorage } = await import('@thelacanians/vue-native-runtime')
    const { getItem } = useAsyncStorage()
    const value = await getItem('token')

    expect(value).toBe('abc123')
  })
})
```

### Testing Event-Driven Composables

Some composables subscribe to global events (e.g., `useNetwork`, `useKeyboard`). Mock `onGlobalEvent` to capture handlers, then trigger events manually:

```ts
const globalHandlers = new Map<string, Function[]>()

beforeEach(() => {
  vi.spyOn(NativeBridge, 'onGlobalEvent').mockImplementation(
    (event: string, handler: (payload: any) => void) => {
      if (!globalHandlers.has(event)) globalHandlers.set(event, [])
      globalHandlers.get(event)!.push(handler)
      return () => {
        const list = globalHandlers.get(event)!
        list.splice(list.indexOf(handler), 1)
      }
    },
  )
})

it('useNetwork updates isConnected on network change', async () => {
  const { useNetwork } = await import('@thelacanians/vue-native-runtime')
  const { isConnected } = useNetwork()

  // Simulate a native event
  for (const fn of globalHandlers.get('networkChange') ?? []) {
    fn({ isConnected: false, connectionType: 'none' })
  }

  expect(isConnected.value).toBe(false)
})
```

## Testing Navigation

The router is pure TypeScript -- no native dependencies. Create a router instance directly and assert on its reactive state.

```ts
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { defineComponent, h } from '@vue/runtime-core'
import { installMockBridge, nextTick } from './helpers'

const mockBridge = installMockBridge()
const { NativeBridge } = await import('@thelacanians/vue-native-runtime')
const { createRouter } = await import('@thelacanians/vue-native-navigation')

const Home = defineComponent({ setup: () => () => h('VView') })
const Login = defineComponent({ setup: () => () => h('VView') })

describe('auth guard', () => {
  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()
  })

  it('redirects unauthenticated users to login', async () => {
    const router = createRouter([
      { name: 'home', component: Home },
      { name: 'login', component: Login },
    ])

    let isLoggedIn = false

    router.beforeEach((to, _from, next) => {
      if (to.config.name === 'home' && !isLoggedIn) {
        next('login')
      } else {
        next()
      }
    })

    await router.push('home')
    await nextTick()
    expect(router.currentRoute.value.config.name).toBe('login')
  })
})
```

## Snapshot Testing

Traditional DOM snapshots do not apply here. Instead, snapshot the bridge operation log. Each render produces a deterministic sequence of JSON operations that you can snapshot:

```ts
it('renders the expected bridge operations', async () => {
  renderComponent(createVNode(VView, { style: { flex: 1 } }, {
    default: () => [createVNode(VText, null, { default: () => 'Hello' })],
  }))
  await nextTick()

  const ops = mockBridge.getOps()
  expect(ops).toMatchSnapshot()
})
```

::: tip
Bridge operation snapshots are a useful regression tool. If a component silently changes the operations it produces, the snapshot diff will surface the change.
:::

::: warning
Reset `NativeBridge` and `mockBridge` in `beforeEach` and call `resetNodeId()` (exported from the runtime) to ensure deterministic node IDs across test runs.
:::

## End-to-End Testing

Unit tests cover your JavaScript logic. For full integration testing against real native views, use platform-specific tools:

| Platform | Tool | Notes |
|----------|------|-------|
| iOS | Xcode UI Tests (XCTest) | Launch the app in a simulator, assert on `accessibilityLabel` values set via Vue Native a11y props |
| Android | Espresso / UI Automator | Similar approach -- query views by content description |
| Cross-platform | Appium | Single test suite targeting both platforms via WebDriver protocol |

E2E tests verify that the native side correctly interprets bridge operations. They are slower and best reserved for critical user flows (onboarding, checkout, authentication).

## Best Practices

1. **Mock the bridge, not the composable.** Spy on `NativeBridge.invokeNativeModule` rather than mocking `useAsyncStorage` itself. This ensures you test the composable's actual logic -- argument mapping, error handling, reactive state updates.

2. **Test behavior, not implementation.** Assert on observable outcomes (reactive values, bridge calls, rendered operations) rather than internal details like private function names.

3. **Reset state between tests.** Always call `mockBridge.reset()` and `NativeBridge.reset()` in `beforeEach`. Without this, operations leak between tests and cause flaky failures.

4. **Use top-level `await import()`.** Because the mock bridge must be installed before the runtime loads, use dynamic imports after calling `installMockBridge()`.

5. **Keep tests fast.** Since there is no DOM or native runtime to start, Vue Native unit tests are pure JavaScript and run in milliseconds. Avoid unnecessary timers or artificial delays.

6. **Test composable cleanup.** Many composables return unsubscribe functions or rely on `onUnmounted`. Verify that event listeners are removed when the composable cleans up to catch memory leaks early.

7. **Snapshot sparingly.** Operation snapshots are helpful for regression detection but can become brittle. Prefer targeted assertions (e.g., "a create operation for VText exists") over full-log snapshots for most tests.
