/**
 * Component render tests — verifies all built-in components produce the correct
 * intrinsic element types, forward props, handle v-model conventions, and
 * render slot content.
 */
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { installMockBridge, nextTick } from './helpers'

const mockBridge = installMockBridge()

const { NativeBridge } = await import('../bridge')
const { resetNodeId } = await import('../node')
const { render } = await import('../renderer')
const { createNativeNode } = await import('../node')

// Import components
const {
  VView, VText, VButton, VInput, VSwitch, VSlider, VImage,
  VScrollView, VList, VModal, VActivityIndicator,
  VKeyboardAvoiding, VSafeArea, VProgressBar, VPicker: _VPicker,
  VSegmentedControl, VActionSheet: _VActionSheet, VStatusBar, VWebView,
  VRefreshControl, VPressable, VSectionList,
  VCheckbox, VRadio, VDropdown, VVideo,
} = await import('../components')

import { createVNode, type VNode } from '@vue/runtime-core'

function renderComponent(vnode: VNode) {
  const root = createNativeNode('__ROOT__')
  NativeBridge.createNode(root.id, '__ROOT__')
  render(vnode, root)
  return root
}

describe('Components', () => {
  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()
    resetNodeId()
  })

  // ---------------------------------------------------------------------------
  // VView
  // ---------------------------------------------------------------------------
  describe('VView', () => {
    it('renders intrinsic VView element', async () => {
      renderComponent(createVNode(VView))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      const viewOps = ops.filter(o => o.args[1] === 'VView')
      expect(viewOps.length).toBeGreaterThanOrEqual(1)
    })

    it('forwards style prop', async () => {
      renderComponent(createVNode(VView, { style: { flex: 1 } }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateStyle')
      const flexOp = ops.find(o => 'flex' in o.args[1])
      expect(flexOp).toBeDefined()
    })

    it('renders slot children', async () => {
      const child = createVNode(VText, null, { default: () => 'Hello' })
      renderComponent(createVNode(VView, null, { default: () => [child] }))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      const types = ops.map(o => o.args[1])
      expect(types).toContain('VView')
      expect(types).toContain('VText')
    })

    it('forwards accessibility props', async () => {
      renderComponent(createVNode(VView, { accessibilityLabel: 'container' }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const labelOp = ops.find(o => o.args[1] === 'accessibilityLabel')
      expect(labelOp).toBeDefined()
      expect(labelOp!.args[2]).toBe('container')
    })
  })

  // ---------------------------------------------------------------------------
  // VText
  // ---------------------------------------------------------------------------
  describe('VText', () => {
    it('renders intrinsic VText element', async () => {
      renderComponent(createVNode(VText, null, { default: () => 'Hello' }))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VText')).toBe(true)
    })

    it('forwards numberOfLines prop', async () => {
      renderComponent(createVNode(VText, { numberOfLines: 2 }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'numberOfLines')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe(2)
    })
  })

  // ---------------------------------------------------------------------------
  // VButton
  // ---------------------------------------------------------------------------
  describe('VButton', () => {
    it('renders intrinsic VButton element', async () => {
      renderComponent(createVNode(VButton))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VButton')).toBe(true)
    })

    it('registers press handler when not disabled', async () => {
      const handler = vi.fn()
      renderComponent(createVNode(VButton, { onPress: handler }))
      await nextTick()
      const ops = mockBridge.getOpsByType('addEventListener')
      expect(ops.some(o => o.args[1] === 'press')).toBe(true)
    })

    it('does NOT register press handler when disabled', async () => {
      const handler = vi.fn()
      renderComponent(createVNode(VButton, { onPress: handler, disabled: true }))
      await nextTick()
      const ops = mockBridge.getOpsByType('addEventListener')
      const pressOps = ops.filter(o => o.args[1] === 'press')
      expect(pressOps).toHaveLength(0)
    })

    it('forwards activeOpacity prop', async () => {
      renderComponent(createVNode(VButton, { activeOpacity: 0.5 }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'activeOpacity')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe(0.5)
    })
  })

  // ---------------------------------------------------------------------------
  // VInput (v-model)
  // ---------------------------------------------------------------------------
  describe('VInput', () => {
    it('renders intrinsic VInput element', async () => {
      renderComponent(createVNode(VInput))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VInput')).toBe(true)
    })

    it('maps modelValue to text prop', async () => {
      renderComponent(createVNode(VInput, { modelValue: 'hello' }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const textProp = ops.find(o => o.args[1] === 'text')
      expect(textProp).toBeDefined()
      expect(textProp!.args[2]).toBe('hello')
    })

    it('forwards placeholder prop', async () => {
      renderComponent(createVNode(VInput, { placeholder: 'Enter...' }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'placeholder')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe('Enter...')
    })

    it('registers changetext event handler', async () => {
      renderComponent(createVNode(VInput, { 'modelValue': '', 'onUpdate:modelValue': vi.fn() }))
      await nextTick()
      const ops = mockBridge.getOpsByType('addEventListener')
      expect(ops.some(o => o.args[1] === 'changetext')).toBe(true)
    })
  })

  // ---------------------------------------------------------------------------
  // VSwitch (v-model)
  // ---------------------------------------------------------------------------
  describe('VSwitch', () => {
    it('renders intrinsic VSwitch element', async () => {
      renderComponent(createVNode(VSwitch))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VSwitch')).toBe(true)
    })

    it('maps modelValue to value prop', async () => {
      renderComponent(createVNode(VSwitch, { modelValue: true }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const valueProp = ops.find(o => o.args[1] === 'value')
      expect(valueProp).toBeDefined()
      expect(valueProp!.args[2]).toBe(true)
    })

    it('registers change event handler', async () => {
      renderComponent(createVNode(VSwitch, { 'onUpdate:modelValue': vi.fn() }))
      await nextTick()
      const ops = mockBridge.getOpsByType('addEventListener')
      expect(ops.some(o => o.args[1] === 'change')).toBe(true)
    })
  })

  // ---------------------------------------------------------------------------
  // VSlider (v-model)
  // ---------------------------------------------------------------------------
  describe('VSlider', () => {
    it('renders intrinsic VSlider element', async () => {
      renderComponent(createVNode(VSlider))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VSlider')).toBe(true)
    })

    it('maps modelValue to value, min to minimumValue, max to maximumValue', async () => {
      renderComponent(createVNode(VSlider, { modelValue: 0.5, min: 0, max: 10 }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      expect(ops.find(o => o.args[1] === 'value')?.args[2]).toBe(0.5)
      expect(ops.find(o => o.args[1] === 'minimumValue')?.args[2]).toBe(0)
      expect(ops.find(o => o.args[1] === 'maximumValue')?.args[2]).toBe(10)
    })
  })

  // ---------------------------------------------------------------------------
  // VCheckbox (v-model)
  // ---------------------------------------------------------------------------
  describe('VCheckbox', () => {
    it('renders intrinsic VCheckbox element', async () => {
      renderComponent(createVNode(VCheckbox))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VCheckbox')).toBe(true)
    })

    it('maps modelValue to value prop', async () => {
      renderComponent(createVNode(VCheckbox, { modelValue: true }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const valueProp = ops.find(o => o.args[1] === 'value')
      expect(valueProp).toBeDefined()
      expect(valueProp!.args[2]).toBe(true)
    })

    it('forwards label prop', async () => {
      renderComponent(createVNode(VCheckbox, { label: 'Accept terms' }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'label')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe('Accept terms')
    })
  })

  // ---------------------------------------------------------------------------
  // VRadio (v-model)
  // ---------------------------------------------------------------------------
  describe('VRadio', () => {
    it('renders intrinsic VRadio element', async () => {
      const options = [{ label: 'A', value: 'a' }, { label: 'B', value: 'b' }]
      renderComponent(createVNode(VRadio, { options }))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VRadio')).toBe(true)
    })

    it('maps modelValue to selectedValue prop', async () => {
      const options = [{ label: 'A', value: 'a' }]
      renderComponent(createVNode(VRadio, { modelValue: 'a', options }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'selectedValue')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe('a')
    })
  })

  // ---------------------------------------------------------------------------
  // VDropdown (v-model)
  // ---------------------------------------------------------------------------
  describe('VDropdown', () => {
    it('renders intrinsic VDropdown element', async () => {
      const options = [{ label: 'US', value: 'us' }]
      renderComponent(createVNode(VDropdown, { options }))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VDropdown')).toBe(true)
    })

    it('maps modelValue to selectedValue prop', async () => {
      const options = [{ label: 'US', value: 'us' }]
      renderComponent(createVNode(VDropdown, { modelValue: 'us', options }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'selectedValue')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe('us')
    })

    it('forwards placeholder prop', async () => {
      const options = [{ label: 'US', value: 'us' }]
      renderComponent(createVNode(VDropdown, { options, placeholder: 'Pick one' }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'placeholder')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe('Pick one')
    })
  })

  // ---------------------------------------------------------------------------
  // VImage
  // ---------------------------------------------------------------------------
  describe('VImage', () => {
    it('renders intrinsic VImage element', async () => {
      renderComponent(createVNode(VImage, { source: { uri: 'http://img.png' } }))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VImage')).toBe(true)
    })

    it('forwards source and resizeMode props', async () => {
      renderComponent(createVNode(VImage, { source: { uri: 'http://img.png' }, resizeMode: 'contain' }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      expect(ops.find(o => o.args[1] === 'resizeMode')?.args[2]).toBe('contain')
    })
  })

  // ---------------------------------------------------------------------------
  // VScrollView
  // ---------------------------------------------------------------------------
  describe('VScrollView', () => {
    it('renders intrinsic VScrollView element', async () => {
      renderComponent(createVNode(VScrollView))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VScrollView')).toBe(true)
    })

    it('forwards horizontal prop', async () => {
      renderComponent(createVNode(VScrollView, { horizontal: true }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'horizontal')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe(true)
    })
  })

  // ---------------------------------------------------------------------------
  // VList
  // ---------------------------------------------------------------------------
  describe('VList', () => {
    it('renders intrinsic VList element', async () => {
      renderComponent(createVNode(VList, { data: [] }))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VList')).toBe(true)
    })

    it('renders item slot for each data entry', async () => {
      const data = ['a', 'b', 'c']
      renderComponent(createVNode(VList, { data }, {
        item: ({ item }: any) => createVNode(VText, null, { default: () => item }),
      }))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      const viewOps = ops.filter(o => o.args[1] === 'VView')
      // 3 item wrapper VViews (items)
      expect(viewOps.length).toBeGreaterThanOrEqual(3)
    })

    it('renders empty slot when data is empty', async () => {
      renderComponent(createVNode(VList, { data: [] }, {
        empty: () => createVNode(VText, null, { default: () => 'No items' }),
      }))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VText')).toBe(true)
    })
  })

  // ---------------------------------------------------------------------------
  // VSectionList
  // ---------------------------------------------------------------------------
  describe('VSectionList', () => {
    it('renders intrinsic VSectionList element', async () => {
      renderComponent(createVNode(VSectionList, { sections: [] }))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VSectionList')).toBe(true)
    })

    it('renders items from sections', async () => {
      const sections = [{ title: 'Fruit', data: ['Apple', 'Banana'] }]
      renderComponent(createVNode(VSectionList, { sections }, {
        item: ({ item }: any) => createVNode(VText, null, { default: () => item }),
      }))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      const textOps = ops.filter(o => o.args[1] === 'VText')
      expect(textOps.length).toBeGreaterThanOrEqual(2)
    })
  })

  // ---------------------------------------------------------------------------
  // VModal
  // ---------------------------------------------------------------------------
  describe('VModal', () => {
    it('renders intrinsic VModal element', async () => {
      renderComponent(createVNode(VModal, { visible: true }))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VModal')).toBe(true)
    })

    it('forwards visible prop', async () => {
      renderComponent(createVNode(VModal, { visible: false }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'visible')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe(false)
    })
  })

  // ---------------------------------------------------------------------------
  // VPressable
  // ---------------------------------------------------------------------------
  describe('VPressable', () => {
    it('renders intrinsic VPressable element', async () => {
      renderComponent(createVNode(VPressable))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VPressable')).toBe(true)
    })

    it('suppresses events when disabled', async () => {
      const handler = vi.fn()
      renderComponent(createVNode(VPressable, { onPress: handler, disabled: true }))
      await nextTick()
      const ops = mockBridge.getOpsByType('addEventListener')
      const pressOps = ops.filter(o => o.args[1] === 'press')
      expect(pressOps).toHaveLength(0)
    })
  })

  // ---------------------------------------------------------------------------
  // VRefreshControl
  // ---------------------------------------------------------------------------
  describe('VRefreshControl', () => {
    it('renders intrinsic VRefreshControl element', async () => {
      renderComponent(createVNode(VRefreshControl))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VRefreshControl')).toBe(true)
    })

    it('forwards refreshing prop', async () => {
      renderComponent(createVNode(VRefreshControl, { refreshing: true }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'refreshing')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe(true)
    })
  })

  // ---------------------------------------------------------------------------
  // VVideo
  // ---------------------------------------------------------------------------
  describe('VVideo', () => {
    it('renders intrinsic VVideo element', async () => {
      renderComponent(createVNode(VVideo, { source: { uri: 'http://vid.mp4' } }))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VVideo')).toBe(true)
    })

    it('forwards autoplay, loop, muted props', async () => {
      renderComponent(createVNode(VVideo, {
        source: { uri: 'http://vid.mp4' },
        autoplay: true,
        loop: true,
        muted: true,
      }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      expect(ops.find(o => o.args[1] === 'autoplay')?.args[2]).toBe(true)
      expect(ops.find(o => o.args[1] === 'loop')?.args[2]).toBe(true)
      expect(ops.find(o => o.args[1] === 'muted')?.args[2]).toBe(true)
    })
  })

  // ---------------------------------------------------------------------------
  // VSegmentedControl
  // ---------------------------------------------------------------------------
  describe('VSegmentedControl', () => {
    it('renders intrinsic VSegmentedControl element', async () => {
      renderComponent(createVNode(VSegmentedControl, { values: ['A', 'B'] }))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VSegmentedControl')).toBe(true)
    })

    it('forwards selectedIndex prop', async () => {
      renderComponent(createVNode(VSegmentedControl, { values: ['A', 'B'], selectedIndex: 1 }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'selectedIndex')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe(1)
    })
  })

  // ---------------------------------------------------------------------------
  // VActivityIndicator
  // ---------------------------------------------------------------------------
  describe('VActivityIndicator', () => {
    it('renders intrinsic VActivityIndicator element', async () => {
      renderComponent(createVNode(VActivityIndicator))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VActivityIndicator')).toBe(true)
    })
  })

  // ---------------------------------------------------------------------------
  // VProgressBar
  // ---------------------------------------------------------------------------
  describe('VProgressBar', () => {
    it('renders intrinsic VProgressBar element', async () => {
      renderComponent(createVNode(VProgressBar))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VProgressBar')).toBe(true)
    })
  })

  // ---------------------------------------------------------------------------
  // VSafeArea
  // ---------------------------------------------------------------------------
  describe('VSafeArea', () => {
    it('renders intrinsic VSafeArea element', async () => {
      renderComponent(createVNode(VSafeArea))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VSafeArea')).toBe(true)
    })
  })

  // ---------------------------------------------------------------------------
  // VKeyboardAvoiding
  // ---------------------------------------------------------------------------
  describe('VKeyboardAvoiding', () => {
    it('renders intrinsic VKeyboardAvoiding element', async () => {
      renderComponent(createVNode(VKeyboardAvoiding))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VKeyboardAvoiding')).toBe(true)
    })
  })

  // ---------------------------------------------------------------------------
  // VStatusBar
  // ---------------------------------------------------------------------------
  describe('VStatusBar', () => {
    it('renders intrinsic VStatusBar element', async () => {
      renderComponent(createVNode(VStatusBar))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VStatusBar')).toBe(true)
    })
  })

  // ---------------------------------------------------------------------------
  // VWebView
  // ---------------------------------------------------------------------------
  describe('VWebView', () => {
    it('renders intrinsic VWebView element', async () => {
      renderComponent(createVNode(VWebView))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VWebView')).toBe(true)
    })
  })
})
