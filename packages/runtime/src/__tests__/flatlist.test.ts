/**
 * VFlatList virtualization tests — verifies that only visible items are rendered.
 */
import { describe, it, expect, beforeEach } from 'vitest'
import { installMockBridge, nextTick } from './helpers'

const mockBridge = installMockBridge()

const { NativeBridge } = await import('../bridge')
const { resetNodeId } = await import('../node')
const { render } = await import('../renderer')
const { createNativeNode } = await import('../node')
const { VFlatList } = await import('../components')

import { createVNode, h } from '@vue/runtime-core'

function renderComponent(vnode: any) {
  const root = createNativeNode('__ROOT__')
  NativeBridge.createNode(root.id, '__ROOT__')
  render(vnode, root)
  return root
}

describe('VFlatList', () => {
  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()
    resetNodeId()
  })

  it('renders a VScrollView as the outer container', async () => {
    const data = Array.from({ length: 100 }, (_, i) => ({ id: i, text: `Item ${i}` }))
    renderComponent(
      createVNode(VFlatList, {
        data,
        itemHeight: 50,
        renderItem: ({ item }: any) => h('VText', {}, item.text),
      }),
    )
    await nextTick()

    const ops = mockBridge.getOpsByType('create')
    const scrollViewOps = ops.filter((o: any) => o.args[1] === 'VScrollView')
    expect(scrollViewOps.length).toBeGreaterThanOrEqual(1)
  })

  it('does NOT render all 1000 items — only a windowed subset', async () => {
    const data = Array.from({ length: 1000 }, (_, i) => ({ id: i, text: `Item ${i}` }))
    renderComponent(
      createVNode(VFlatList, {
        data,
        itemHeight: 50,
        windowSize: 2,
        renderItem: ({ item }: any) => h('VText', {}, item.text),
      }),
    )
    await nextTick()

    const ops = mockBridge.getOpsByType('create')
    // Count VText nodes created (one per rendered item)
    const textOps = ops.filter((o: any) => o.args[1] === 'VText')

    // With 1000 items and windowSize 2, we should render FAR fewer than 1000
    // Initial viewport estimate = itemHeight * 20 = 1000px
    // Buffer = 1000 * 2 = 2000px above + below
    // Total render range = -2000 to 3000 = ~60 items
    expect(textOps.length).toBeLessThan(200)
    expect(textOps.length).toBeGreaterThan(0)
  })

  it('positions items absolutely at correct offsets', async () => {
    const data = [{ id: 0 }, { id: 1 }, { id: 2 }]
    renderComponent(
      createVNode(VFlatList, {
        data,
        itemHeight: 60,
        renderItem: ({ item }: any) => h('VText', {}, `Item ${item.id}`),
      }),
    )
    await nextTick()

    const ops = mockBridge.getOpsByType('updateStyle')
    // Look for position:absolute and top values
    const topOps = ops.filter((o: any) => o.args[1]?.top !== undefined && o.args[1]?.position === 'absolute')
    const topValues = topOps.map((o: any) => o.args[1].top).sort((a: number, b: number) => a - b)

    // Items should be at top: 0, 60, 120
    expect(topValues).toContain(0)
    expect(topValues).toContain(60)
    expect(topValues).toContain(120)
  })

  it('sets the inner container height to total content height', async () => {
    const data = Array.from({ length: 50 }, (_, i) => ({ id: i }))
    renderComponent(
      createVNode(VFlatList, {
        data,
        itemHeight: 40,
        renderItem: () => h('VText', {}, 'x'),
      }),
    )
    await nextTick()

    const ops = mockBridge.getOpsByType('updateStyle')
    // Total height = 50 * 40 = 2000
    const heightOp = ops.find((o: any) => o.args[1]?.height === 2000)
    expect(heightOp).toBeDefined()
  })

  it('renders empty slot when data is empty', async () => {
    renderComponent(
      createVNode(
        VFlatList,
        {
          data: [],
          itemHeight: 50,
        },
        {
          empty: () => h('VText', {}, 'No items'),
          item: ({ item: _item }: any) => h('VText', {}, 'x'),
        },
      ),
    )
    await nextTick()

    // h('VText', {}, 'No items') results in setElementText, not createText
    const ops = mockBridge.getOpsByType('setElementText')
    const emptyText = ops.find((o: any) => o.args[1] === 'No items')
    expect(emptyText).toBeDefined()
  })

  it('supports slot-based renderItem via #item slot', async () => {
    const data = [{ id: 0, text: 'Hello' }]
    renderComponent(
      createVNode(
        VFlatList,
        {
          data,
          itemHeight: 50,
        },
        {
          item: ({ item }: any) => h('VText', {}, item.text),
        },
      ),
    )
    await nextTick()

    // h('VText', {}, text) results in setElementText, not createText
    const ops = mockBridge.getOpsByType('setElementText')
    const helloText = ops.find((o: any) => o.args[1] === 'Hello')
    expect(helloText).toBeDefined()
  })

  // Bug fix test: header should not overlap first item (P1 2.2)
  it('offsets items by headerHeight when header slot is provided', async () => {
    const data = [{ id: 0 }, { id: 1 }]
    renderComponent(
      createVNode(
        VFlatList,
        {
          data,
          itemHeight: 50,
          headerHeight: 80,
        },
        {
          header: () => h('VText', {}, 'Header'),
          item: ({ item }: any) => h('VText', {}, `Item ${item.id}`),
        },
      ),
    )
    await nextTick()

    const ops = mockBridge.getOpsByType('updateStyle')
    // Items should be offset by headerHeight (80), so top: 80, 130 instead of 0, 50
    const topOps = ops.filter((o: any) => o.args[1]?.top !== undefined && o.args[1]?.position === 'absolute')
    const topValues = topOps.map((o: any) => o.args[1].top).sort((a: number, b: number) => a - b)

    // Header is at top:0, items at 80 and 130
    expect(topValues).toContain(0) // header
    expect(topValues).toContain(80) // first item
    expect(topValues).toContain(130) // second item
    // first item should NOT be at top:0 (that's the header)
    const itemTops = topValues.filter((t: number) => t > 0)
    expect(itemTops[0]).toBe(80)
  })

  it('includes headerHeight in totalHeight', async () => {
    const data = Array.from({ length: 10 }, (_, i) => ({ id: i }))
    renderComponent(
      createVNode(
        VFlatList,
        {
          data,
          itemHeight: 40,
          headerHeight: 100,
        },
        {
          header: () => h('VText', {}, 'Header'),
          item: () => h('VText', {}, 'x'),
        },
      ),
    )
    await nextTick()

    const ops = mockBridge.getOpsByType('updateStyle')
    // Total height = 10 * 40 + 100 = 500
    const heightOp = ops.find((o: any) => o.args[1]?.height === 500)
    expect(heightOp).toBeDefined()
  })
})
