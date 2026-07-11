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
  VRefreshControl, VPressable, VSectionList, VTabBar, VDrawer,
  VDrawerItem, VDrawerSection,
  VCheckbox, VRadio, VDropdown, VVideo,
  VToolbar, VSplitView, VOutlineView,
  VTransition, VTransitionGroup, KeepAlive, VSuspense, defineAsyncComponent,
} = await import('../components')

import {
  createVNode,
  defineComponent,
  onActivated,
  onDeactivated,
  onMounted,
  onUnmounted,
  ref,
  type Component,
  type VNode,
} from '@vue/runtime-core'

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

    it('renders the title shorthand as VText when no default slot is provided', async () => {
      renderComponent(createVNode(VButton, { title: 'Save' }))
      await nextTick()

      expect(mockBridge.getOpsByType('create').some(o => o.args[1] === 'VText')).toBe(true)
      expect(mockBridge.getOpsByType('createText').some(o => o.args[1] === 'Save')).toBe(true)
    })

    it('prefers default slot content over the title shorthand', async () => {
      renderComponent(createVNode(VButton, { title: 'Ignored' }, {
        default: () => createVNode(VText, null, { default: () => 'Custom' }),
      }))
      await nextTick()

      const text = mockBridge.getOpsByType('createText').map(o => o.args[1])
      expect(text).toContain('Custom')
      expect(text).not.toContain('Ignored')
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

    it('forwards onTintColor as a native prop instead of an event listener', async () => {
      renderComponent(createVNode(VSwitch, { onTintColor: '#34C759' }))
      await nextTick()

      const propOps = mockBridge.getOpsByType('updateProp')
      expect(propOps.find(op => op.args[1] === 'onTintColor')?.args[2]).toBe('#34C759')
      expect(mockBridge.getOpsByType('addEventListener').some(op => op.args[1] === 'tintColor')).toBe(false)
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

    it('extracts the numeric value from native change payloads', async () => {
      const updateModelValue = vi.fn()
      const change = vi.fn()
      renderComponent(createVNode(VSlider, {
        'onUpdate:modelValue': updateModelValue,
        'onChange': change,
      }))
      await nextTick()

      const changeListener = mockBridge.getOpsByType('addEventListener')
        .find(op => op.args[1] === 'change')
      expect(changeListener).toBeDefined()

      NativeBridge.handleNativeEvent(changeListener!.args[0], 'change', { value: 0.75 })
      expect(updateModelValue).toHaveBeenCalledWith(0.75)
      expect(change).toHaveBeenCalledWith(0.75)
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

    it('uses scroll view fallback for horizontal lists on Apple platforms', async () => {
      const previousPlatform = (globalThis as any).__PLATFORM__
      ;(globalThis as any).__PLATFORM__ = 'macos'

      renderComponent(createVNode(VList, { data: ['A'], horizontal: true }, {
        item: ({ item }: any) => createVNode(VText, null, { default: () => item }),
      }))
      await nextTick()

      const createOps = mockBridge.getOpsByType('create')
      expect(createOps.some(o => o.args[1] === 'VScrollView')).toBe(true)
      expect(createOps.some(o => o.args[1] === 'VList')).toBe(false)

      if (previousPlatform === undefined) {
        delete (globalThis as any).__PLATFORM__
      } else {
        ;(globalThis as any).__PLATFORM__ = previousPlatform
      }
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
  // VTabBar
  // ---------------------------------------------------------------------------
  describe('VTabBar', () => {
    it('renders pressable tabs for each config entry', async () => {
      renderComponent(createVNode(VTabBar, {
        tabs: [
          { id: 'home', label: 'Home' },
          { id: 'settings', label: 'Settings', badge: 2 },
        ],
        activeTab: 'home',
      }))
      await nextTick()

      const createOps = mockBridge.getOpsByType('create')
      expect(createOps.some(o => o.args[1] === 'VView')).toBe(true)
      expect(createOps.filter(o => o.args[1] === 'VPressable')).toHaveLength(2)
    })

    it('emits change when a tab is pressed', async () => {
      const changeSpy = vi.fn()
      const updateSpy = vi.fn()

      renderComponent(createVNode(VTabBar, {
        'tabs': [
          { name: 'home', label: 'Home' },
          { name: 'settings', label: 'Settings' },
        ],
        'modelValue': 'home',
        'onChange': changeSpy,
        'onUpdate:modelValue': updateSpy,
      }))
      await nextTick()

      const pressables = mockBridge.getOpsByType('create').filter(o => o.args[1] === 'VPressable')
      NativeBridge.handleNativeEvent(pressables[1].args[0], 'press', null)

      expect(changeSpy).toHaveBeenCalledWith('settings')
      expect(updateSpy).toHaveBeenCalledWith('settings')
    })
  })

  // ---------------------------------------------------------------------------
  // macOS components
  // ---------------------------------------------------------------------------
  describe('macOS-specific components', () => {
    it('renders VToolbar intrinsic element', async () => {
      renderComponent(createVNode(VToolbar, {
        items: [{ id: 'new', label: 'New', icon: 'doc.badge.plus' }],
      }))
      await nextTick()

      const createOps = mockBridge.getOpsByType('create')
      expect(createOps.some(o => o.args[1] === 'VToolbar')).toBe(true)
    })

    it('renders VSplitView children', async () => {
      const child = createVNode(VView)
      renderComponent(createVNode(VSplitView, { direction: 'horizontal' }, { default: () => [child] }))
      await nextTick()

      const createOps = mockBridge.getOpsByType('create')
      expect(createOps.some(o => o.args[1] === 'VSplitView')).toBe(true)
    })

    it('renders VOutlineView intrinsic element', async () => {
      renderComponent(createVNode(VOutlineView, {
        data: [{ id: 'src', label: 'src' }],
      }))
      await nextTick()

      const createOps = mockBridge.getOpsByType('create')
      expect(createOps.some(o => o.args[1] === 'VOutlineView')).toBe(true)
    })
  })

  // ---------------------------------------------------------------------------
  // VTransition
  // ---------------------------------------------------------------------------
  describe('VTransition', () => {
    it('does not create a native Transition element', async () => {
      const child = createVNode(VView)
      renderComponent(createVNode(VTransition, null, { default: () => [child] }))
      await nextTick()

      const createTypes = mockBridge.getOpsByType('create').map(o => o.args[1])
      expect(createTypes).toContain('VView')
      expect(createTypes).not.toContain('Transition')
    })

    it('renders VTransitionGroup as a native container without TransitionGroup nodes', async () => {
      renderComponent(createVNode(VTransitionGroup, { tag: 'VView' }, {
        default: () => [
          createVNode(VText, { key: 'a' }, { default: () => 'A' }),
          createVNode(VText, { key: 'b' }, { default: () => 'B' }),
        ],
      }))
      await nextTick()

      const createTypes = mockBridge.getOpsByType('create').map(o => o.args[1])
      expect(createTypes).toContain('VView')
      expect(createTypes.filter(type => type === 'VText')).toHaveLength(2)
      expect(createTypes).not.toContain('TransitionGroup')
    })

    it('animates normal show and hide flows through the native Animation module', async () => {
      const animation = vi.spyOn(NativeBridge, 'invokeNativeModule').mockResolvedValue(undefined)
      const show = ref(false)
      const Root = defineComponent({
        render() {
          return createVNode(VTransition, {
            show: show.value,
            duration: 25,
            enterFrom: { opacity: 0, translateY: 10 },
            enterTo: { opacity: 1, translateY: 0 },
            leaveTo: { opacity: 0, translateY: -10 },
            easing: 'easeInOut',
          }, {
            default: () => [createVNode(VView)],
          })
        },
      })

      renderComponent(createVNode(Root))
      await nextTick()

      show.value = true
      await nextTick()
      await nextTick()
      expect(animation).toHaveBeenCalledWith(
        'Animation',
        'timing',
        expect.arrayContaining([expect.any(Number), { opacity: 1, translateY: 0 }]),
      )

      animation.mockClear()
      show.value = false
      await nextTick()
      await nextTick()
      expect(animation).toHaveBeenCalledWith(
        'Animation',
        'timing',
        expect.arrayContaining([expect.any(Number), { opacity: 0, translateY: -10 }]),
      )
      animation.mockRestore()
    })
  })

  describe('renderer-native state components', () => {
    it('KeepAlive preserves instances and runs activate/deactivate lifecycle hooks', async () => {
      const events: string[] = []
      const makeComponent = (name: string) => defineComponent({
        name,
        setup() {
          onMounted(() => events.push(`${name}:mounted`))
          onUnmounted(() => events.push(`${name}:unmounted`))
          onActivated(() => events.push(`${name}:activated`))
          onDeactivated(() => events.push(`${name}:deactivated`))
          return () => createVNode(VText, null, { default: () => name })
        },
      })
      const A = makeComponent('A')
      const B = makeComponent('B')
      const current = ref<'A' | 'B'>('A')
      const Root = defineComponent({
        render() {
          const component = current.value === 'A' ? A : B
          return createVNode(KeepAlive, null, {
            default: () => [createVNode(component, { key: current.value })],
          })
        },
      })

      const root = renderComponent(createVNode(Root))
      await nextTick()
      current.value = 'B'
      await nextTick()
      current.value = 'A'
      await nextTick()

      expect(events.filter(event => event === 'A:mounted')).toHaveLength(1)
      expect(events).toContain('A:deactivated')
      expect(events.filter(event => event === 'A:activated').length).toBeGreaterThanOrEqual(2)
      expect(events).not.toContain('A:unmounted')

      render(null, root)
      await nextTick()
      expect(events).toContain('A:unmounted')
      expect(events).toContain('B:unmounted')
    })

    it('VSuspense renders fallback and defineAsyncComponent unwraps module defaults', async () => {
      type AsyncModule = {
        default: Component
        [Symbol.toStringTag]: 'Module'
      }
      let resolveLoader!: (component: AsyncModule) => void
      const Loaded = defineComponent({
        render: () => createVNode(VText, null, { default: () => 'Loaded' }),
      })
      const AsyncChild = defineAsyncComponent(() => new Promise<AsyncModule>((resolve) => {
        resolveLoader = resolve
      }))

      renderComponent(createVNode(VSuspense, null, {
        default: () => createVNode(AsyncChild),
        fallback: () => createVNode(VText, null, { default: () => 'Loading' }),
      }))
      await nextTick()

      expect(mockBridge.getOpsByType('createText').some(op => op.args[1] === 'Loading')).toBe(true)

      resolveLoader({ default: Loaded, [Symbol.toStringTag]: 'Module' })
      await nextTick()
      await nextTick()

      expect(mockBridge.getOpsByType('createText').some(op => op.args[1] === 'Loaded')).toBe(true)
    })
  })

  // ---------------------------------------------------------------------------
  // VDrawer
  // ---------------------------------------------------------------------------
  describe('VDrawer', () => {
    it('reacts to open prop changes after mount', async () => {
      const open = ref(false)
      const openSpy = vi.fn()
      const Root = defineComponent({
        render() {
          return createVNode(VDrawer, { open: open.value, onOpen: openSpy }, {
            default: () => [createVNode(VText, null, { default: () => 'Menu' })],
          })
        },
      })

      renderComponent(createVNode(Root))
      await nextTick()

      mockBridge.reset()
      open.value = true
      await nextTick()

      const createOps = mockBridge.getOpsByType('create')
      expect(createOps.some(o => o.args[1] === 'VPressable')).toBe(true)
      expect(openSpy).toHaveBeenCalledTimes(1)
    })

    it('closes on item press when closeOnPress is enabled', async () => {
      const updateSpy = vi.fn()
      const closeSpy = vi.fn()
      const itemSpy = vi.fn()

      renderComponent(createVNode(VDrawer, {
        'open': true,
        'onUpdate:open': updateSpy,
        'onClose': closeSpy,
      }, {
        default: () => [
          createVNode((VDrawer as any).Item, {
            label: 'Home',
            onPress: itemSpy,
          }),
        ],
      }))
      await nextTick()

      const pressables = mockBridge.getOpsByType('create').filter(o => o.args[1] === 'VPressable')
      const itemNodeId = pressables[pressables.length - 1].args[0]

      NativeBridge.handleNativeEvent(itemNodeId, 'press', null)
      await nextTick()

      expect(itemSpy).toHaveBeenCalledTimes(1)
      expect(updateSpy).toHaveBeenCalledWith(false)
      expect(closeSpy).toHaveBeenCalledTimes(1)
    })

    it('does not close on item press when closeOnPress is disabled', async () => {
      const updateSpy = vi.fn()
      const closeSpy = vi.fn()
      const itemSpy = vi.fn()

      renderComponent(createVNode(VDrawer, {
        'open': true,
        'closeOnPress': false,
        'onUpdate:open': updateSpy,
        'onClose': closeSpy,
      }, {
        default: () => [
          createVNode((VDrawer as any).Item, {
            label: 'Home',
            onPress: itemSpy,
          }),
        ],
      }))
      await nextTick()

      const pressables = mockBridge.getOpsByType('create').filter(o => o.args[1] === 'VPressable')
      const itemNodeId = pressables[pressables.length - 1].args[0]

      NativeBridge.handleNativeEvent(itemNodeId, 'press', null)
      await nextTick()

      expect(itemSpy).toHaveBeenCalledTimes(1)
      expect(updateSpy).not.toHaveBeenCalled()
      expect(closeSpy).not.toHaveBeenCalled()
    })

    it('forwards style attrs to the drawer container', async () => {
      renderComponent(createVNode(VDrawer, {
        open: true,
        style: { backgroundColor: '#123456' },
      }, {
        default: () => [createVNode(VText, null, { default: () => 'Menu' })],
      }))
      await nextTick()

      const styleOps = mockBridge.getOpsByType('updateStyle')
      expect(styleOps.some(o => o.args[1]?.backgroundColor === '#123456')).toBe(true)
    })

    it('supports a custom backdrop color without forcing outside-press close', async () => {
      renderComponent(createVNode(VDrawer, {
        open: true,
        overlayColor: '#112233',
        closeOnPressOutside: false,
      }, {
        default: () => [createVNode(VText, null, { default: () => 'Menu' })],
      }))
      await nextTick()

      const styleOps = mockBridge.getOpsByType('updateStyle')
      expect(styleOps.some(o => o.args[1]?.backgroundColor === '#112233')).toBe(true)
      expect(mockBridge.getOpsByType('addEventListener').some(o => o.args[1] === 'press')).toBe(false)
    })

    it('renders footer content after the default slot', async () => {
      renderComponent(createVNode(VDrawer, { open: true }, {
        default: () => createVNode(VText, null, { default: () => 'Menu' }),
        footer: () => createVNode(VText, null, { default: () => 'Version 1' }),
      }))
      await nextTick()

      const text = mockBridge.getOpsByType('createText').map(o => o.args[1])
      expect(text).toContain('Menu')
      expect(text).toContain('Version 1')
    })

    it('exposes active drawer items as selected', async () => {
      renderComponent(createVNode(VDrawerItem, { label: 'Home', active: true }))
      await nextTick()

      expect(mockBridge.getOpsByType('updateProp').some(o =>
        o.args[1] === 'accessibilityState'
        && o.args[2]?.disabled === false
        && o.args[2]?.selected === true,
      )).toBe(true)
      expect(mockBridge.getOpsByType('updateStyle')
        .some(o => o.args[1]?.backgroundColor === '#EAF3FF')).toBe(true)
    })

    it('renders a zero-valued badge', async () => {
      renderComponent(createVNode(VDrawerItem, { label: 'Inbox', badge: 0 }))
      await nextTick()

      expect(mockBridge.getOpsByType('createText').some(o => o.args[1] === '0')).toBe(true)
    })

    it('exports VDrawerItem as a direct component alias', async () => {
      renderComponent(createVNode(VDrawerItem, { label: 'Home' }))
      await nextTick()

      const createOps = mockBridge.getOpsByType('create')
      expect(createOps.some(o => o.args[1] === 'VPressable')).toBe(true)
      expect(createOps.some(o => o.args[1] === 'VText')).toBe(true)
    })

    it('exports VDrawerSection as a direct component alias', async () => {
      renderComponent(createVNode(VDrawerSection, { title: 'Navigation' }, {
        default: () => [createVNode(VText, null, { default: () => 'Home' })],
      }))
      await nextTick()

      const createOps = mockBridge.getOpsByType('create')
      expect(createOps.filter(o => o.args[1] === 'VText').length).toBeGreaterThanOrEqual(2)
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

    it('sends playback intent before the source', async () => {
      renderComponent(createVNode(VVideo, {
        source: { uri: 'http://vid.mp4' },
        autoplay: false,
        paused: false,
      }))
      await nextTick()

      const propNames = mockBridge
        .getOpsByType('updateProp')
        .map(o => o.args[1])
      const sourceIndex = propNames.indexOf('source')

      expect(sourceIndex).toBeGreaterThan(-1)
      expect(propNames.indexOf('autoplay')).toBeLessThan(sourceIndex)
      expect(propNames.indexOf('paused')).toBeLessThan(sourceIndex)
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

    it('forwards animating prop', async () => {
      renderComponent(createVNode(VActivityIndicator, { animating: false }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'animating')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe(false)
    })

    it('forwards color prop', async () => {
      renderComponent(createVNode(VActivityIndicator, { color: '#FF0000' }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'color')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe('#FF0000')
    })

    it('forwards size prop', async () => {
      renderComponent(createVNode(VActivityIndicator, { size: 'large' }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'size')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe('large')
    })

    it('defaults animating to true', async () => {
      renderComponent(createVNode(VActivityIndicator))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'animating')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe(true)
    })

    it('forwards hidesWhenStopped prop', async () => {
      renderComponent(createVNode(VActivityIndicator, { hidesWhenStopped: false }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'hidesWhenStopped')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe(false)
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

    it('forwards progress value', async () => {
      renderComponent(createVNode(VProgressBar, { progress: 0.75 }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'progress')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe(0.75)
    })

    it('forwards progressTintColor prop', async () => {
      renderComponent(createVNode(VProgressBar, { progressTintColor: '#007AFF' }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'progressTintColor')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe('#007AFF')
    })

    it('forwards trackTintColor prop', async () => {
      renderComponent(createVNode(VProgressBar, { trackTintColor: '#E0E0E0' }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'trackTintColor')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe('#E0E0E0')
    })

    it('forwards animated prop', async () => {
      renderComponent(createVNode(VProgressBar, { animated: false }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'animated')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe(false)
    })

    it('defaults progress to 0', async () => {
      renderComponent(createVNode(VProgressBar))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'progress')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe(0)
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

    it('renders slot children', async () => {
      const child = createVNode(VText, null, { default: () => 'Safe content' })
      renderComponent(createVNode(VSafeArea, null, { default: () => [child] }))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VText')).toBe(true)
    })

    it('forwards style prop', async () => {
      renderComponent(createVNode(VSafeArea, { style: { flex: 1, backgroundColor: '#FFF' } }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateStyle')
      expect(ops.length).toBeGreaterThanOrEqual(1)
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

    it('renders slot children', async () => {
      const child = createVNode(VInput, { placeholder: 'Type...' })
      renderComponent(createVNode(VKeyboardAvoiding, null, { default: () => [child] }))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VInput')).toBe(true)
    })

    it('forwards testID prop', async () => {
      renderComponent(createVNode(VKeyboardAvoiding, { testID: 'kb-avoid' }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'testID')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe('kb-avoid')
    })

    it('forwards style prop', async () => {
      renderComponent(createVNode(VKeyboardAvoiding, { style: { flex: 1 } }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateStyle')
      expect(ops.length).toBeGreaterThanOrEqual(1)
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

    it('forwards barStyle prop with light-content', async () => {
      renderComponent(createVNode(VStatusBar, { barStyle: 'light-content' }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'barStyle')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe('light-content')
    })

    it('forwards barStyle prop with dark-content', async () => {
      renderComponent(createVNode(VStatusBar, { barStyle: 'dark-content' }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'barStyle')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe('dark-content')
    })

    it('defaults barStyle to default', async () => {
      renderComponent(createVNode(VStatusBar))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'barStyle')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe('default')
    })

    it('forwards hidden prop', async () => {
      renderComponent(createVNode(VStatusBar, { hidden: true }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'hidden')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe(true)
    })

    it('forwards animated prop', async () => {
      renderComponent(createVNode(VStatusBar, { animated: false }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const prop = ops.find(o => o.args[1] === 'animated')
      expect(prop).toBeDefined()
      expect(prop!.args[2]).toBe(false)
    })
  })

  // ---------------------------------------------------------------------------
  // VWebView
  // ---------------------------------------------------------------------------
  describe('VWebView', () => {
    it('renders intrinsic VWebView element', async () => {
      renderComponent(createVNode(VWebView, { source: { uri: 'https://example.com' } }))
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VWebView')).toBe(true)
    })

    it('forwards source uri prop', async () => {
      renderComponent(createVNode(VWebView, { source: { uri: 'https://example.com' } }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const sourceProp = ops.find(o => o.args[1] === 'source')
      expect(sourceProp).toBeDefined()
      expect(sourceProp!.args[2].uri).toBe('https://example.com')
    })

    it('registers onLoad event handler', async () => {
      const handler = vi.fn()
      renderComponent(createVNode(VWebView, { source: { uri: 'https://example.com' }, onLoad: handler }))
      await nextTick()
      const ops = mockBridge.getOpsByType('addEventListener')
      expect(ops.some(o => o.args[1] === 'load')).toBe(true)
    })

    it('registers onError event handler', async () => {
      const handler = vi.fn()
      renderComponent(createVNode(VWebView, { source: { uri: 'https://example.com' }, onError: handler }))
      await nextTick()
      const ops = mockBridge.getOpsByType('addEventListener')
      expect(ops.some(o => o.args[1] === 'error')).toBe(true)
    })

    it('blocks javascript: URI scheme', async () => {
      const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {})
      renderComponent(createVNode(VWebView, { source: { uri: 'javascript:alert(1)' } }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const sourceProp = ops.find(o => o.args[1] === 'source')
      expect(sourceProp).toBeDefined()
      expect(sourceProp!.args[2].uri).toBeUndefined()
      warnSpy.mockRestore()
    })

    it('blocks data:text/html URI scheme', async () => {
      const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {})
      renderComponent(createVNode(VWebView, { source: { uri: 'data:text/html,<h1>XSS</h1>' } }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const sourceProp = ops.find(o => o.args[1] === 'source')
      expect(sourceProp).toBeDefined()
      expect(sourceProp!.args[2].uri).toBeUndefined()
      warnSpy.mockRestore()
    })

    it('forwards javaScriptEnabled before the initial source navigation', async () => {
      renderComponent(createVNode(VWebView, { source: { uri: 'https://example.com' }, javaScriptEnabled: false }))
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      const javaScriptIndex = ops.findIndex(o => o.args[1] === 'javaScriptEnabled')
      const sourceIndex = ops.findIndex(o => o.args[1] === 'source')

      expect(javaScriptIndex).toBeGreaterThanOrEqual(0)
      expect(sourceIndex).toBeGreaterThanOrEqual(0)
      expect(ops[javaScriptIndex]!.args[2]).toBe(false)
      expect(javaScriptIndex).toBeLessThan(sourceIndex)
    })
  })

  // ---------------------------------------------------------------------------
  // VAlertDialog
  // ---------------------------------------------------------------------------
  describe('VAlertDialog', () => {
    it('renders intrinsic VAlertDialog element', async () => {
      const { VAlertDialog } = await import('../components/VAlertDialog')
      renderComponent(createVNode(VAlertDialog, { visible: true }))
      await nextTick()
      // VAlertDialog has a debounce timer, wait for it
      await new Promise(resolve => setTimeout(resolve, 60))
      const ops = mockBridge.getOpsByType('create')
      expect(ops.some(o => o.args[1] === 'VAlertDialog')).toBe(true)
    })

    it('forwards title and message props', async () => {
      const { VAlertDialog } = await import('../components/VAlertDialog')
      renderComponent(createVNode(VAlertDialog, { visible: true, title: 'Warning', message: 'Are you sure?' }))
      await nextTick()
      await new Promise(resolve => setTimeout(resolve, 60))
      const ops = mockBridge.getOpsByType('updateProp')
      const titleProp = ops.find(o => o.args[1] === 'title')
      expect(titleProp).toBeDefined()
      expect(titleProp!.args[2]).toBe('Warning')
      const msgProp = ops.find(o => o.args[1] === 'message')
      expect(msgProp).toBeDefined()
      expect(msgProp!.args[2]).toBe('Are you sure?')
    })

    it('forwards buttons array', async () => {
      const { VAlertDialog } = await import('../components/VAlertDialog')
      const buttons = [
        { label: 'Cancel', style: 'cancel' as const },
        { label: 'Delete', style: 'destructive' as const },
      ]
      renderComponent(createVNode(VAlertDialog, { visible: true, buttons }))
      await nextTick()
      await new Promise(resolve => setTimeout(resolve, 60))
      const ops = mockBridge.getOpsByType('updateProp')
      const btnProp = ops.find(o => o.args[1] === 'buttons')
      expect(btnProp).toBeDefined()
      expect(btnProp!.args[2]).toHaveLength(2)
      expect(btnProp!.args[2][0].label).toBe('Cancel')
      expect(btnProp!.args[2][1].label).toBe('Delete')
    })

    it('registers onConfirm event handler', async () => {
      const { VAlertDialog } = await import('../components/VAlertDialog')
      const handler = vi.fn()
      renderComponent(createVNode(VAlertDialog, { visible: true, onConfirm: handler }))
      await nextTick()
      await new Promise(resolve => setTimeout(resolve, 60))
      const ops = mockBridge.getOpsByType('addEventListener')
      expect(ops.some(o => o.args[1] === 'confirm')).toBe(true)
    })

    it('registers onCancel event handler', async () => {
      const { VAlertDialog } = await import('../components/VAlertDialog')
      const handler = vi.fn()
      renderComponent(createVNode(VAlertDialog, { visible: true, onCancel: handler }))
      await nextTick()
      await new Promise(resolve => setTimeout(resolve, 60))
      const ops = mockBridge.getOpsByType('addEventListener')
      expect(ops.some(o => o.args[1] === 'cancel')).toBe(true)
    })

    it('builds buttons from confirmText/cancelText when buttons array is empty', async () => {
      const { VAlertDialog } = await import('../components/VAlertDialog')
      renderComponent(createVNode(VAlertDialog, {
        visible: true,
        confirmText: 'OK',
        cancelText: 'Dismiss',
      }))
      await nextTick()
      await new Promise(resolve => setTimeout(resolve, 60))
      const ops = mockBridge.getOpsByType('updateProp')
      const btnProp = ops.find(o => o.args[1] === 'buttons')
      expect(btnProp).toBeDefined()
      expect(btnProp!.args[2]).toHaveLength(2)
      expect(btnProp!.args[2][0].label).toBe('Dismiss')
      expect(btnProp!.args[2][0].style).toBe('cancel')
      expect(btnProp!.args[2][1].label).toBe('OK')
      expect(btnProp!.args[2][1].style).toBe('default')
    })

    it('visible prop controls rendering via debounce', async () => {
      const { VAlertDialog } = await import('../components/VAlertDialog')
      renderComponent(createVNode(VAlertDialog, { visible: false }))
      await nextTick()
      await new Promise(resolve => setTimeout(resolve, 60))
      const ops = mockBridge.getOpsByType('updateProp')
      const visibleProp = ops.find(o => o.args[1] === 'visible')
      expect(visibleProp).toBeDefined()
      expect(visibleProp!.args[2]).toBe(false)
    })

    it('configures content and handlers before presenting', async () => {
      const { VAlertDialog } = await import('../components/VAlertDialog')
      renderComponent(createVNode(VAlertDialog, {
        visible: true,
        title: 'Confirm',
        message: 'Continue?',
        buttons: [{ label: 'OK' }],
        onConfirm: vi.fn(),
      }))
      await nextTick()

      const ops = mockBridge.getOps()
      const visibleIndex = ops.findIndex(op => op.op === 'updateProp' && op.args[1] === 'visible')
      const titleIndex = ops.findIndex(op => op.op === 'updateProp' && op.args[1] === 'title')
      const messageIndex = ops.findIndex(op => op.op === 'updateProp' && op.args[1] === 'message')
      const buttonsIndex = ops.findIndex(op => op.op === 'updateProp' && op.args[1] === 'buttons')
      const confirmIndex = ops.findIndex(op => op.op === 'addEventListener' && op.args[1] === 'confirm')

      expect(visibleIndex).toBeGreaterThan(titleIndex)
      expect(visibleIndex).toBeGreaterThan(messageIndex)
      expect(visibleIndex).toBeGreaterThan(buttonsIndex)
      expect(visibleIndex).toBeGreaterThan(confirmIndex)
    })
  })

  describe('VActionSheet', () => {
    it('configures content and handlers before presenting', async () => {
      renderComponent(createVNode(_VActionSheet, {
        visible: true,
        title: 'Choose',
        message: 'Select an action',
        actions: [{ label: 'Edit' }, { label: 'Cancel', style: 'cancel' }],
        onAction: vi.fn(),
        onCancel: vi.fn(),
      }))
      await nextTick()

      const ops = mockBridge.getOps()
      const visibleIndex = ops.findIndex(op => op.op === 'updateProp' && op.args[1] === 'visible')
      const titleIndex = ops.findIndex(op => op.op === 'updateProp' && op.args[1] === 'title')
      const messageIndex = ops.findIndex(op => op.op === 'updateProp' && op.args[1] === 'message')
      const actionsIndex = ops.findIndex(op => op.op === 'updateProp' && op.args[1] === 'actions')
      const actionHandlerIndex = ops.findIndex(op => op.op === 'addEventListener' && op.args[1] === 'action')
      const cancelHandlerIndex = ops.findIndex(op => op.op === 'addEventListener' && op.args[1] === 'cancel')

      expect(visibleIndex).toBeGreaterThan(titleIndex)
      expect(visibleIndex).toBeGreaterThan(messageIndex)
      expect(visibleIndex).toBeGreaterThan(actionsIndex)
      expect(visibleIndex).toBeGreaterThan(actionHandlerIndex)
      expect(visibleIndex).toBeGreaterThan(cancelHandlerIndex)
    })
  })
})
