import { describe, it, expect, beforeEach, vi } from 'vitest'
import { installMockBridge, nextTick, withSetup } from './helpers'
import { ref } from '@vue/runtime-core'

const mockBridge = installMockBridge()

const { useGesture, useComposedGestures } = await import('../composables/useGesture')
const { NativeBridge } = await import('../bridge')

describe('useGesture', () => {
  const eventHandlers = new Map<string, (payload: unknown) => void>()

  beforeEach(() => {
    mockBridge.reset()
    // Tests reuse hardcoded node ids (42, 1, ...): clear the bridge's
    // subscription registry so this test's addEventListener ops are not
    // deduped against leftovers from the previous test.
    NativeBridge.reset()
    eventHandlers.clear()

    const globals = globalThis as typeof globalThis & {
      __VN_handleEvent?: (nodeId: number, eventName: string, payload: unknown) => void
    }

    globals.__VN_handleEvent = (nodeId: number, eventName: string, payload: unknown) => {
      eventHandlers.set(`${nodeId}:${eventName}`, payload as ((p: unknown) => void))
    }
  })

  describe('basic setup', () => {
    it('returns refs initialized to null', async () => {
      const gestures = await withSetup(() => useGesture())

      expect(gestures.pan.value).toBeNull()
      expect(gestures.pinch.value).toBeNull()
      expect(gestures.rotate.value).toBeNull()
      expect(gestures.swipeLeft.value).toBeNull()
      expect(gestures.press.value).toBeNull()
      expect(gestures.gestureState.value).toBeNull()
      expect(gestures.activeGesture.value).toBeNull()
      expect(gestures.isGesturing.value).toBe(false)
    })

    it('attaches to a view when target is provided', async () => {
      await withSetup(() => {
        const nodeRef = ref({ id: 42 })
        useGesture(nodeRef, { pan: true })
        return {}
      })

      await nextTick()

      const addOps = mockBridge.getOpsByType('addEventListener')
      expect(addOps.length).toBe(1)
      expect(addOps[0].args).toEqual([42, 'pan'])
    })

    it('marks native-driven gestures via the nativeDrivenGestures prop', async () => {
      await withSetup(() => {
        const nodeRef = ref({ id: 42 })
        useGesture(nodeRef, { pan: { nativeDrive: true } })
        return {}
      })

      await nextTick()

      const propOps = mockBridge.getOpsByType('updateProp')
      const nativeDriveOp = propOps.find(o => o.args[1] === 'nativeDrivenGestures')
      expect(nativeDriveOp).toBeDefined()
      expect(nativeDriveOp?.args[0]).toBe(42)
      expect(nativeDriveOp?.args[2]).toEqual(['pan'])
    })

    it('attaches to a numeric node id', async () => {
      await withSetup(() => {
        useGesture(123, { press: true })
        return {}
      })

      await nextTick()

      const addOps = mockBridge.getOpsByType('addEventListener')
      expect(addOps.length).toBe(1)
      expect(addOps[0].args).toEqual([123, 'press'])
    })

    it('attaches to a NativeNode object', async () => {
      await withSetup(() => {
        useGesture({ id: 456 }, { pinch: true })
        return {}
      })

      await nextTick()

      const addOps = mockBridge.getOpsByType('addEventListener')
      expect(addOps.length).toBe(1)
      expect(addOps[0].args).toEqual([456, 'pinch'])
    })
  })

  describe('gesture subscriptions', () => {
    it('subscribes to pan gesture when pan option is true', async () => {
      await withSetup(() => {
        useGesture({ id: 1 }, { pan: true })
        return {}
      })

      await nextTick()

      const addOps = mockBridge.getOpsByType('addEventListener')
      expect(addOps.length).toBe(1)
      expect(addOps[0].args[1]).toBe('pan')
    })

    it('subscribes to multiple gestures', async () => {
      await withSetup(() => {
        useGesture({ id: 1 }, { pan: true, pinch: true, rotate: true })
        return {}
      })

      await nextTick()

      const addOps = mockBridge.getOpsByType('addEventListener')
      expect(addOps.length).toBe(3)
      const events = addOps.map(op => op.args[1])
      expect(events).toContain('pan')
      expect(events).toContain('pinch')
      expect(events).toContain('rotate')
    })

    it('manual on() coexists with the declarative option binding', async () => {
      const manualCallback = vi.fn()
      const gestures = await withSetup(() => useGesture({ id: 1 }, { pan: true }))
      gestures.on('pan', manualCallback)
      await nextTick()

      // Both subscriptions fire: the declarative one keeps updating the ref
      // and the manual callback receives the same event.
      const state = { translationX: 10, translationY: 0, velocityX: 0, velocityY: 0, state: 'changed' }
      NativeBridge.handleNativeEvent(1, 'pan', state)
      expect(manualCallback).toHaveBeenCalledWith(state)
      expect(gestures.pan.value).toEqual(state)
    })

    it('subscribes to swipe gestures', async () => {
      await withSetup(() => {
        useGesture({ id: 1 }, {
          swipeLeft: true,
          swipeRight: true,
          swipeUp: true,
          swipeDown: true,
        })
        return {}
      })

      await nextTick()

      const addOps = mockBridge.getOpsByType('addEventListener')
      expect(addOps.length).toBe(4)
      const events = addOps.map(op => op.args[1])
      expect(events).toContain('swipeLeft')
      expect(events).toContain('swipeRight')
      expect(events).toContain('swipeUp')
      expect(events).toContain('swipeDown')
    })

    it('subscribes to tap gestures', async () => {
      await withSetup(() => {
        useGesture({ id: 1 }, { press: true, longPress: true, doubleTap: true })
        return {}
      })

      await nextTick()

      const addOps = mockBridge.getOpsByType('addEventListener')
      expect(addOps.length).toBe(3)
      const events = addOps.map(op => op.args[1])
      expect(events).toContain('press')
      expect(events).toContain('longPress')
      expect(events).toContain('doubleTap')
    })

    it('subscribes to force touch and hover', async () => {
      await withSetup(() => {
        useGesture({ id: 1 }, { forceTouch: true, hover: true })
        return {}
      })

      await nextTick()

      const addOps = mockBridge.getOpsByType('addEventListener')
      expect(addOps.length).toBe(2)
      const events = addOps.map(op => op.args[1])
      expect(events).toContain('forceTouch')
      expect(events).toContain('hover')
    })

    it('does not subscribe when option is false', async () => {
      await withSetup(() => {
        useGesture({ id: 1 }, { pan: false, pinch: false })
        return {}
      })

      await nextTick()

      const addOps = mockBridge.getOpsByType('addEventListener')
      expect(addOps.length).toBe(0)
    })
  })

  describe('gesture config', () => {
    it('accepts enabled option in config', async () => {
      await withSetup(() => {
        useGesture({ id: 1 }, { pan: { enabled: true } })
        return {}
      })

      await nextTick()

      const addOps = mockBridge.getOpsByType('addEventListener')
      expect(addOps.length).toBe(1)
      expect(addOps[0].args[1]).toBe('pan')
    })
  })

  describe('detach', () => {
    it('removes all event listeners on detach', async () => {
      const gestures = await withSetup(() => useGesture({ id: 1 }, { pan: true, pinch: true, rotate: true }))
      await nextTick()

      const addOps = mockBridge.getOpsByType('addEventListener')
      expect(addOps.length).toBeGreaterThanOrEqual(3)

      gestures.detach()
      await nextTick()

      const removeOps = mockBridge.getOpsByType('removeEventListener')
      const events = removeOps.map(op => op.args[1])
      expect(events).toContain('pan')
      expect(events).toContain('pinch')
      expect(events).toContain('rotate')
    })
  })
})

describe('useComposedGestures', () => {
  beforeEach(() => {
    mockBridge.reset()
    // Tests reuse node id 1: clear leftover subscriptions so addEventListener
    // ops are not deduped against the previous test's listeners.
    NativeBridge.reset()
  })

  it('subscribes to pan, pinch, and rotate by default', async () => {
    await withSetup(() => {
      useComposedGestures({ id: 1 })
      return {}
    })

    await nextTick()

    const addOps = mockBridge.getOpsByType('addEventListener')
    expect(addOps.length).toBe(3)
    const events = addOps.map(op => op.args[1])
    expect(events).toContain('pan')
    expect(events).toContain('pinch')
    expect(events).toContain('rotate')
  })

  it('can disable specific gestures', async () => {
    await withSetup(() => {
      useComposedGestures({ id: 1 }, { pan: false })
      return {}
    })

    await nextTick()

    const addOps = mockBridge.getOpsByType('addEventListener')
    const events = addOps.map(op => op.args[1])
    expect(events).not.toContain('pan')
    expect(events).toContain('pinch')
    expect(events).toContain('rotate')
  })
})
