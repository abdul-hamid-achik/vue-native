/**
 * Renderer resilience tests — verify error handling in nodeOps.
 *
 * These tests ensure that errors in the bridge layer (patchProp, patchStyle,
 * insert, remove) are caught and do not crash the Vue render loop.
 */
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { installMockBridge, nextTick } from './helpers'

const mockBridge = installMockBridge()

const { NativeBridge } = await import('../bridge')
const { nodeOps } = await import('../renderer')
const { resetNodeId } = await import('../node')

describe('Renderer resilience', () => {
  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()
    resetNodeId()
  })

  describe('patchProp error handling', () => {
    it('catches errors in style patching and continues', () => {
      const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {})

      // Create a valid element
      const el = nodeOps.createElement('VView')

      // Temporarily break the bridge
      const originalUpdateStyle = NativeBridge.updateStyle.bind(NativeBridge)
      NativeBridge.updateStyle = () => {
        throw new Error('Style update failed')
      }

      // Should NOT throw
      expect(() => {
        nodeOps.patchProp(el, 'style', null, { backgroundColor: '#FF0000' })
      }).not.toThrow()

      expect(errorSpy).toHaveBeenCalledWith(
        expect.stringContaining('Error patching style'),
        expect.any(Error),
      )

      NativeBridge.updateStyle = originalUpdateStyle
      errorSpy.mockRestore()
    })

    it('catches errors in event listener registration and continues', () => {
      const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {})

      const el = nodeOps.createElement('VButton')

      const originalAddEvent = NativeBridge.addEventListener.bind(NativeBridge)
      NativeBridge.addEventListener = () => {
        throw new Error('Event registration failed')
      }

      expect(() => {
        nodeOps.patchProp(el, 'onPress', null, () => {})
      }).not.toThrow()

      expect(errorSpy).toHaveBeenCalledWith(
        expect.stringContaining('Error patching prop "onPress"'),
        expect.any(Error),
      )

      NativeBridge.addEventListener = originalAddEvent
      errorSpy.mockRestore()
    })

    it('catches errors in prop update and continues', () => {
      const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {})

      const el = nodeOps.createElement('VInput')

      const originalUpdateProp = NativeBridge.updateProp.bind(NativeBridge)
      NativeBridge.updateProp = () => {
        throw new Error('Prop update failed')
      }

      expect(() => {
        nodeOps.patchProp(el, 'placeholder', null, 'Type here')
      }).not.toThrow()

      expect(errorSpy).toHaveBeenCalledWith(
        expect.stringContaining('Error patching prop "placeholder"'),
        expect.any(Error),
      )

      NativeBridge.updateProp = originalUpdateProp
      errorSpy.mockRestore()
    })
  })

  describe('insert error handling', () => {
    it('catches errors during bridge insert and continues', () => {
      const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {})

      const parent = nodeOps.createElement('VView')
      const child = nodeOps.createElement('VText')

      const originalAppendChild = NativeBridge.appendChild.bind(NativeBridge)
      NativeBridge.appendChild = () => {
        throw new Error('appendChild failed')
      }

      // Should not throw — the JS-side tree should still be consistent
      expect(() => {
        nodeOps.insert(child, parent, null)
      }).not.toThrow()

      // JS-side tree should still have the child
      expect(parent.children).toContain(child)
      expect(child.parent).toBe(parent)

      expect(errorSpy).toHaveBeenCalledWith(
        expect.stringContaining('Error inserting node'),
        expect.any(Error),
      )

      NativeBridge.appendChild = originalAppendChild
      errorSpy.mockRestore()
    })

    it('catches errors during bridge insertBefore and continues', () => {
      const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {})

      const parent = nodeOps.createElement('VView')
      const child1 = nodeOps.createElement('VText')
      const child2 = nodeOps.createElement('VText')
      nodeOps.insert(child1, parent, null)

      const originalInsertBefore = NativeBridge.insertBefore.bind(NativeBridge)
      NativeBridge.insertBefore = () => {
        throw new Error('insertBefore failed')
      }

      expect(() => {
        nodeOps.insert(child2, parent, child1)
      }).not.toThrow()

      // JS-side tree should still have both children in correct order
      expect(parent.children[0]).toBe(child2)
      expect(parent.children[1]).toBe(child1)

      NativeBridge.insertBefore = originalInsertBefore
      errorSpy.mockRestore()
    })
  })

  describe('remove error handling', () => {
    it('catches errors during bridge removeChild and continues', () => {
      const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {})

      const parent = nodeOps.createElement('VView')
      const child = nodeOps.createElement('VText')
      nodeOps.insert(child, parent, null)

      const originalRemoveChild = NativeBridge.removeChild.bind(NativeBridge)
      NativeBridge.removeChild = () => {
        throw new Error('removeChild failed')
      }

      expect(() => {
        nodeOps.remove(child)
      }).not.toThrow()

      // JS-side tree should have the child removed
      expect(parent.children).not.toContain(child)
      expect(child.parent).toBeNull()

      expect(errorSpy).toHaveBeenCalledWith(
        expect.stringContaining('Error removing node'),
        expect.any(Error),
      )

      NativeBridge.removeChild = originalRemoveChild
      errorSpy.mockRestore()
    })
  })

  describe('comment node handling', () => {
    it('insert with comment anchor falls back to appendChild', async () => {
      const parent = nodeOps.createElement('VView')
      const comment = nodeOps.createComment('v-if')
      const child = nodeOps.createElement('VText')
      nodeOps.insert(comment, parent, null)
      await nextTick()
      mockBridge.reset()

      nodeOps.insert(child, parent, comment)
      await nextTick()

      // Since comment is the only child (anchor) and there's no non-comment sibling
      // after it, should fall back to appendChild
      const appendOps = mockBridge.getOpsByType('appendChild')
      expect(appendOps).toHaveLength(1)
      expect(appendOps[0].args[1]).toBe(child.id)
    })

    it('insert with comment anchor finds next non-comment sibling', async () => {
      const parent = nodeOps.createElement('VView')
      const realChild = nodeOps.createElement('VText')
      const comment = nodeOps.createComment('v-if')

      nodeOps.insert(comment, parent, null)
      nodeOps.insert(realChild, parent, null)
      await nextTick()
      mockBridge.reset()

      const newChild = nodeOps.createElement('VButton')
      nodeOps.insert(newChild, parent, comment)
      await nextTick()

      // Should use insertBefore with realChild as the anchor
      const insertOps = mockBridge.getOpsByType('insertBefore')
      expect(insertOps).toHaveLength(1)
      expect(insertOps[0].args).toEqual([parent.id, newChild.id, realChild.id])
    })

    it('does not send removeChild for comment nodes', async () => {
      const parent = nodeOps.createElement('VView')
      const comment = nodeOps.createComment('v-if')
      nodeOps.insert(comment, parent, null)
      await nextTick()
      mockBridge.reset()

      nodeOps.remove(comment)
      await nextTick()

      expect(mockBridge.getOpsByType('removeChild')).toHaveLength(0)
      expect(parent.children).not.toContain(comment)
    })
  })

  describe('tree consistency', () => {
    it('re-parenting removes child from old parent', async () => {
      const parent1 = nodeOps.createElement('VView')
      const parent2 = nodeOps.createElement('VView')
      const child = nodeOps.createElement('VText')

      nodeOps.insert(child, parent1, null)
      expect(parent1.children).toContain(child)

      nodeOps.insert(child, parent2, null)
      expect(parent1.children).not.toContain(child)
      expect(parent2.children).toContain(child)
      expect(child.parent).toBe(parent2)
    })

    it('setElementText clears all JS children', async () => {
      const parent = nodeOps.createElement('VView')
      const child1 = nodeOps.createElement('VText')
      const child2 = nodeOps.createElement('VText')

      nodeOps.insert(child1, parent, null)
      nodeOps.insert(child2, parent, null)
      expect(parent.children).toHaveLength(2)

      nodeOps.setElementText(parent, 'replacement text')
      expect(parent.children).toHaveLength(0)
      expect(child1.parent).toBeNull()
      expect(child2.parent).toBeNull()
    })

    it('nextSibling returns correct sibling', () => {
      const parent = nodeOps.createElement('VView')
      const child1 = nodeOps.createElement('VText')
      const child2 = nodeOps.createElement('VButton')
      const child3 = nodeOps.createElement('VInput')

      nodeOps.insert(child1, parent, null)
      nodeOps.insert(child2, parent, null)
      nodeOps.insert(child3, parent, null)

      expect(nodeOps.nextSibling(child1)).toBe(child2)
      expect(nodeOps.nextSibling(child2)).toBe(child3)
      expect(nodeOps.nextSibling(child3)).toBeNull()
    })

    it('parentNode returns null after removal', () => {
      const parent = nodeOps.createElement('VView')
      const child = nodeOps.createElement('VText')
      nodeOps.insert(child, parent, null)

      expect(nodeOps.parentNode(child)).toBe(parent)

      nodeOps.remove(child)
      expect(nodeOps.parentNode(child)).toBeNull()
    })
  })
})
