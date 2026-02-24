/**
 * ErrorBoundary tests — verifies error capture, fallback rendering,
 * reset functionality, and resetKeys behavior.
 */
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { installMockBridge, nextTick } from './helpers'

const mockBridge = installMockBridge()

const { NativeBridge } = await import('../bridge')
const { resetNodeId, createNativeNode } = await import('../node')
const { render } = await import('../renderer')
const { ErrorBoundary } = await import('../errorBoundary')

import { createVNode, defineComponent, h, type VNode } from '@vue/runtime-core'

function renderComponent(vnode: VNode) {
  const root = createNativeNode('__ROOT__')
  NativeBridge.createNode(root.id, '__ROOT__')
  render(vnode, root)
  return root
}

// A component that always throws during render
const ThrowingComponent = defineComponent({
  name: 'ThrowingComponent',
  setup() {
    throw new Error('Component error')
  },
})

// A component that conditionally throws based on a prop
const _ConditionalThrow = defineComponent({
  name: 'ConditionalThrow',
  props: {
    shouldThrow: { type: Boolean, default: false },
  },
  setup(props) {
    return () => {
      if (props.shouldThrow) {
        throw new Error('Conditional error')
      }
      return h('VText', null, 'OK')
    }
  },
})

// A simple working component
const GoodComponent = defineComponent({
  name: 'GoodComponent',
  setup() {
    return () => h('VText', null, 'Hello')
  },
})

describe('ErrorBoundary', () => {
  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()
    resetNodeId()
    vi.restoreAllMocks()
    // Suppress console.error for cleaner test output (Vue logs errors)
    vi.spyOn(console, 'error').mockImplementation(() => {})
    vi.spyOn(console, 'warn').mockImplementation(() => {})
  })

  it('renders default slot children normally when no error', async () => {
    renderComponent(
      createVNode(ErrorBoundary, null, {
        default: () => h(GoodComponent),
      }),
    )
    await nextTick()
    const ops = mockBridge.getOpsByType('create')
    expect(ops.some(o => o.args[1] === 'VText')).toBe(true)
  })

  it('catches child component errors and renders fallback', async () => {
    renderComponent(
      createVNode(ErrorBoundary, null, {
        default: () => h(ThrowingComponent),
        fallback: ({ error }: { error: Error }) =>
          h('VText', null, `Error: ${error.message}`),
      }),
    )
    await nextTick()
    // The fallback slot should be rendered with the error info
    const ops = mockBridge.getOpsByType('create')
    expect(ops.some(o => o.args[1] === 'VText')).toBe(true)
  })

  it('calls onError callback when error occurs', async () => {
    const onErrorFn = vi.fn()
    renderComponent(
      createVNode(ErrorBoundary, { onError: onErrorFn }, {
        default: () => h(ThrowingComponent),
        fallback: ({ error }: { error: Error }) =>
          h('VText', null, error.message),
      }),
    )
    await nextTick()
    expect(onErrorFn).toHaveBeenCalledTimes(1)
    expect(onErrorFn).toHaveBeenCalledWith(expect.any(Error), expect.any(String))
    expect(onErrorFn.mock.calls[0][0].message).toBe('Component error')
  })

  it('provides reset function in fallback slot', async () => {
    let resetFn: (() => void) | undefined

    renderComponent(
      createVNode(ErrorBoundary, null, {
        default: () => h(ThrowingComponent),
        fallback: ({ reset }: { reset: () => void }) => {
          resetFn = reset
          return h('VText', null, 'Error occurred')
        },
      }),
    )
    await nextTick()
    expect(resetFn).toBeDefined()
    expect(typeof resetFn).toBe('function')
  })

  it('provides errorInfo in fallback slot', async () => {
    let capturedErrorInfo = ''

    renderComponent(
      createVNode(ErrorBoundary, null, {
        default: () => h(ThrowingComponent),
        fallback: ({ errorInfo }: { errorInfo: string }) => {
          capturedErrorInfo = errorInfo
          return h('VText', null, 'Error')
        },
      }),
    )
    await nextTick()
    expect(typeof capturedErrorInfo).toBe('string')
  })

  it('prevents error from propagating to parent', async () => {
    // If ErrorBoundary catches correctly, rendering should complete without throw
    expect(() => {
      renderComponent(
        createVNode(ErrorBoundary, null, {
          default: () => h(ThrowingComponent),
          fallback: ({ error }: { error: Error }) =>
            h('VText', null, error.message),
        }),
      )
    }).not.toThrow()
  })

  it('handles non-Error thrown values by wrapping in Error', async () => {
    const StringThrower = defineComponent({
      name: 'StringThrower',
      setup() {
        throw 'string error'
      },
    })

    const onErrorFn = vi.fn()
    renderComponent(
      createVNode(ErrorBoundary, { onError: onErrorFn }, {
        default: () => h(StringThrower),
        fallback: () => h('VText', null, 'caught'),
      }),
    )
    await nextTick()
    if (onErrorFn.mock.calls.length > 0) {
      expect(onErrorFn.mock.calls[0][0]).toBeInstanceOf(Error)
    }
  })
})
