/**
 * Integration tests — mount real Vue components and verify the full render cycle.
 *
 * These tests use the actual Vue runtime to mount components, trigger state
 * changes, and verify that the correct bridge operations are emitted.
 * This catches issues that unit tests miss by exercising the full pipeline:
 *   Vue component → custom renderer → NativeBridge → mock flush
 */
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { installMockBridge, nextTick } from './helpers'

const mockBridge = installMockBridge()

const { NativeBridge } = await import('../bridge')
const { resetNodeId } = await import('../node')
const { h, ref, nextTick: vueNextTick, defineComponent } = await import('@vue/runtime-core')
const { render } = await import('../renderer')
const { createNativeNode } = await import('../node')

describe('Integration: full Vue render cycle', () => {
  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()
    resetNodeId()
  })

  it('renders a simple VView with VText child', async () => {
    const root = createNativeNode('__ROOT__')

    const App = defineComponent({
      render() {
        return h('VView', { style: { padding: 16 } }, [
          h('VText', {}, 'Hello Vue Native'),
        ])
      },
    })

    render(h(App), root)
    await nextTick()

    // Should have: create VView, create VText, createText "Hello Vue Native",
    // appendChild VText into VView, appendChild text into VText,
    // updateStyle padding, appendChild VView into root
    const createOps = mockBridge.getOpsByType('create')
    expect(createOps.length).toBeGreaterThanOrEqual(1)
    expect(createOps.some(o => o.args[1] === 'VView')).toBe(true)
    expect(createOps.some(o => o.args[1] === 'VText')).toBe(true)

    const appendOps = mockBridge.getOpsByType('appendChild')
    expect(appendOps.length).toBeGreaterThanOrEqual(1)
  })

  it('updates text when reactive state changes', async () => {
    const root = createNativeNode('__ROOT__')
    const count = ref(0)

    const App = defineComponent({
      setup() {
        return () => h('VView', {}, [
          // Use a text node directly (not wrapped in VText)
          // Vue's renderer calls setText for text node updates
          `Count: ${count.value}`,
        ])
      },
    })

    render(h(App), root)
    await nextTick()
    mockBridge.reset()

    // Trigger state change
    count.value = 42
    await vueNextTick()
    await nextTick()

    // Vue updates text nodes via setText. The text might also be re-created
    // depending on the rendering strategy (keyed vs unkeyed).
    const allOps = mockBridge.getOps()
    const textOps = allOps.filter(
      o =>
        (o.op === 'setText' && String(o.args[1]).includes('42'))
        || (o.op === 'createText' && String(o.args[1]).includes('42')),
    )
    expect(textOps.length).toBeGreaterThanOrEqual(1)
  })

  it('handles conditional rendering (v-if equivalent)', async () => {
    const root = createNativeNode('__ROOT__')
    const show = ref(true)

    const App = defineComponent({
      setup() {
        return () => h('VView', {}, [
          show.value ? h('VText', { key: 'text' }, 'Visible') : null,
        ])
      },
    })

    render(h(App), root)
    await nextTick()

    const initialCreates = mockBridge.getOpsByType('create')
    expect(initialCreates.some(o => o.args[1] === 'VText')).toBe(true)

    mockBridge.reset()

    // Hide the text
    show.value = false
    await vueNextTick()
    await nextTick()

    const removeOps = mockBridge.getOpsByType('removeChild')
    expect(removeOps.length).toBeGreaterThanOrEqual(1)

    mockBridge.reset()

    // Show the text again
    show.value = true
    await vueNextTick()
    await nextTick()

    const reCreateOps = mockBridge.getOpsByType('create')
    expect(reCreateOps.some(o => o.args[1] === 'VText')).toBe(true)
  })

  it('handles list rendering', async () => {
    const root = createNativeNode('__ROOT__')
    const items = ref(['Apple', 'Banana', 'Cherry'])

    const App = defineComponent({
      setup() {
        return () => h('VView', {},
          items.value.map(item =>
            h('VText', { key: item }, item),
          ),
        )
      },
    })

    render(h(App), root)
    await nextTick()

    const createOps = mockBridge.getOpsByType('create')
    const textCreates = createOps.filter(o => o.args[1] === 'VText')
    expect(textCreates.length).toBe(3)

    mockBridge.reset()

    // Add an item
    items.value = ['Apple', 'Banana', 'Cherry', 'Date']
    await vueNextTick()
    await nextTick()

    const newCreates = mockBridge.getOpsByType('create')
    expect(newCreates.some(o => o.args[1] === 'VText')).toBe(true)

    mockBridge.reset()

    // Remove an item
    items.value = ['Apple', 'Cherry', 'Date']
    await vueNextTick()
    await nextTick()

    const removeOps = mockBridge.getOpsByType('removeChild')
    expect(removeOps.length).toBeGreaterThanOrEqual(1)
  })

  it('patches style diffs correctly on state change', async () => {
    const root = createNativeNode('__ROOT__')
    const isActive = ref(false)

    const App = defineComponent({
      setup() {
        return () => h('VView', {
          style: {
            backgroundColor: isActive.value ? '#00FF00' : '#FF0000',
            padding: 16, // unchanged
          },
        })
      },
    })

    render(h(App), root)
    await nextTick()
    mockBridge.reset()

    isActive.value = true
    await vueNextTick()
    await nextTick()

    const styleOps = mockBridge.getOpsByType('updateStyle')
    // Should only update backgroundColor (not padding since it didn't change)
    const bgOps = styleOps.filter(o => 'backgroundColor' in o.args[1])
    expect(bgOps).toHaveLength(1)
    expect(bgOps[0].args[1].backgroundColor).toBe('#00FF00')

    // padding should NOT be re-sent
    const paddingOps = styleOps.filter(o => 'padding' in o.args[1])
    expect(paddingOps).toHaveLength(0)
  })

  it('handles event listeners on components', async () => {
    const root = createNativeNode('__ROOT__')
    const pressHandler = vi.fn()

    const App = defineComponent({
      setup() {
        return () => h('VButton', { onPress: pressHandler }, 'Click me')
      },
    })

    render(h(App), root)
    await nextTick()

    const addEventOps = mockBridge.getOpsByType('addEventListener')
    expect(addEventOps.some(o => o.args[1] === 'press')).toBe(true)

    // Simulate native event
    const buttonNodeId = addEventOps.find(o => o.args[1] === 'press')!.args[0]
    NativeBridge.handleNativeEvent(buttonNodeId, 'press', null)

    expect(pressHandler).toHaveBeenCalled()
  })

  it('cleans up event listeners when component unmounts', async () => {
    const root = createNativeNode('__ROOT__')
    const show = ref(true)
    const handler = vi.fn()

    const App = defineComponent({
      setup() {
        return () => h('VView', {}, [
          show.value ? h('VButton', { key: 'btn', onPress: handler }) : null,
        ])
      },
    })

    render(h(App), root)
    await nextTick()
    mockBridge.reset()

    show.value = false
    await vueNextTick()
    await nextTick()

    // Should see removeChild (and possibly removeEventListener) for the button
    const removeOps = mockBridge.getOpsByType('removeChild')
    expect(removeOps.length).toBeGreaterThanOrEqual(1)
  })

  it('handles nested components', async () => {
    const root = createNativeNode('__ROOT__')

    const Card = defineComponent({
      props: {
        title: String,
      },
      setup(props) {
        return () => h('VView', { style: { padding: 8 } }, [
          h('VText', {}, props.title || ''),
        ])
      },
    })

    const App = defineComponent({
      setup() {
        return () => h('VView', {}, [
          h(Card, { title: 'Card 1' }),
          h(Card, { title: 'Card 2' }),
        ])
      },
    })

    render(h(App), root)
    await nextTick()

    const createOps = mockBridge.getOpsByType('create')
    // Root VView + 2 Card VViews + 2 VTexts = at least 5 creates
    expect(createOps.length).toBeGreaterThanOrEqual(5)

    const viewCreates = createOps.filter(o => o.args[1] === 'VView')
    expect(viewCreates.length).toBe(3) // root + 2 cards

    const textCreates = createOps.filter(o => o.args[1] === 'VText')
    expect(textCreates.length).toBe(2)
  })

  it('batches all operations from a single state change into one flush', async () => {
    const root = createNativeNode('__ROOT__')
    const count = ref(0)
    let flushCount = 0

    const originalFlush = (globalThis as any).__VN_flushOperations
    ;(globalThis as any).__VN_flushOperations = (json: string) => {
      flushCount++
      originalFlush(json)
    }

    const App = defineComponent({
      setup() {
        return () => h('VView', {}, [
          h('VText', {}, `A: ${count.value}`),
          h('VText', {}, `B: ${count.value}`),
          h('VText', {}, `C: ${count.value}`),
        ])
      },
    })

    render(h(App), root)
    await nextTick()

    flushCount = 0

    // Single state change that affects multiple nodes
    count.value = 1
    await vueNextTick()
    await nextTick()

    // All updates should be batched into a single flush call
    expect(flushCount).toBe(1)

    ;(globalThis as any).__VN_flushOperations = originalFlush
  })
})
