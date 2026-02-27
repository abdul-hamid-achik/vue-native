/**
 * Renderer tests — exercise nodeOps directly.
 *
 * Rather than mounting a full Vue component tree, we call nodeOps methods
 * directly. This is the same pattern Vue's own @vue/runtime-test uses:
 * it tests the RendererOptions object (nodeOps) in isolation, which avoids
 * needing a real component lifecycle while still verifying every bridge call.
 */
import { describe, it, expect, beforeEach } from 'vitest'
import { installMockBridge, nextTick } from './helpers'

// Install mock bridge BEFORE importing any module that touches NativeBridge
const mockBridge = installMockBridge()

const { NativeBridge } = await import('../bridge')
const { createNativeNode, createTextNode: _createTextNode, createCommentNode: _createCommentNode, resetNodeId } = await import('../node')
const { nodeOps } = await import('../renderer')

describe('NativeRenderer (nodeOps)', () => {
  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()
    resetNodeId()
  })

  // -------------------------------------------------------------------------
  // createNativeNode helper (node.ts)
  // -------------------------------------------------------------------------
  describe('createNativeNode', () => {
    it('creates a node with the correct type', () => {
      const node = createNativeNode('VView')
      expect(node.type).toBe('VView')
    })

    it('assigns unique ids to each node', () => {
      const ids = new Set(Array.from({ length: 10 }, () => createNativeNode('VView').id))
      expect(ids.size).toBe(10)
    })

    it('returns a markRaw node (not reactive)', () => {
      const node = createNativeNode('VView')
      // Vue marks raw objects with __v_skip = true
      expect((node as any).__v_skip).toBe(true)
    })
  })

  // -------------------------------------------------------------------------
  // createElement
  // -------------------------------------------------------------------------
  describe('createElement', () => {
    it('creates a node with the correct type', async () => {
      const el = nodeOps.createElement('VView')
      expect(el.type).toBe('VView')
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops[0].args[1]).toBe('VView')
    })

    it('sends a create operation for each element', async () => {
      nodeOps.createElement('VView')
      nodeOps.createElement('VButton')
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops).toHaveLength(2)
      expect(ops.map(o => o.args[1])).toEqual(['VView', 'VButton'])
    })
  })

  // -------------------------------------------------------------------------
  // createText
  // -------------------------------------------------------------------------
  describe('createText', () => {
    it('creates a text node with __TEXT__ type', async () => {
      const text = nodeOps.createText('Hello')
      expect(text.type).toBe('__TEXT__')
      await nextTick()
      const ops = mockBridge.getOpsByType('createText')
      expect(ops[0].args[1]).toBe('Hello')
    })
  })

  // -------------------------------------------------------------------------
  // createComment
  // -------------------------------------------------------------------------
  describe('createComment', () => {
    it('creates a comment node with __COMMENT__ type', () => {
      const comment = nodeOps.createComment('v-if')
      expect(comment.type).toBe('__COMMENT__')
    })

    it('does NOT send any bridge operation for comments', async () => {
      nodeOps.createComment('v-if')
      await nextTick()
      expect(mockBridge.getOps()).toHaveLength(0)
    })
  })

  // -------------------------------------------------------------------------
  // setText
  // -------------------------------------------------------------------------
  describe('setText', () => {
    it('updates the node text property and sends setText op', async () => {
      const text = nodeOps.createText('initial')
      await nextTick()
      mockBridge.reset()

      nodeOps.setText(text, 'updated')
      expect(text.text).toBe('updated')
      await nextTick()

      const ops = mockBridge.getOpsByType('setText')
      expect(ops[0].args[1]).toBe('updated')
    })
  })

  // -------------------------------------------------------------------------
  // setElementText
  // -------------------------------------------------------------------------
  describe('setElementText', () => {
    it('clears JS children and sends setElementText op', async () => {
      const parent = nodeOps.createElement('VView')
      const child = nodeOps.createElement('VText')
      nodeOps.insert(child, parent, null)
      await nextTick()
      mockBridge.reset()

      nodeOps.setElementText(parent, 'inline text')
      expect(parent.children).toHaveLength(0)
      await nextTick()

      const ops = mockBridge.getOpsByType('setElementText')
      expect(ops[0].args[1]).toBe('inline text')
    })
  })

  // -------------------------------------------------------------------------
  // patchProp — style
  // -------------------------------------------------------------------------
  describe('patchProp: style', () => {
    it('sends a single batched updateStyle for all style properties that change', async () => {
      const el = nodeOps.createElement('VView')
      await nextTick()
      mockBridge.reset()

      nodeOps.patchProp(el, 'style', null, { backgroundColor: '#FF0000', opacity: 1 })
      await nextTick()

      const ops = mockBridge.getOpsByType('updateStyle')
      expect(ops).toHaveLength(1)
      const styles = ops[0].args[1]
      expect(styles.backgroundColor).toBe('#FF0000')
      expect(styles.opacity).toBe(1)
    })

    it('sends null for style properties that are removed', async () => {
      const el = nodeOps.createElement('VView')
      nodeOps.patchProp(el, 'style', null, { backgroundColor: '#FF0000', opacity: 1 })
      await nextTick()
      mockBridge.reset()

      // Remove backgroundColor by omitting it from next style
      nodeOps.patchProp(el, 'style', { backgroundColor: '#FF0000', opacity: 1 }, { opacity: 1 })
      await nextTick()

      const ops = mockBridge.getOpsByType('updateStyle')
      const removedOp = ops.find(o => 'backgroundColor' in o.args[1])
      expect(removedOp?.args[1].backgroundColor).toBeNull()
    })

    it('skips style properties that have not changed', async () => {
      const el = nodeOps.createElement('VView')
      nodeOps.patchProp(el, 'style', null, { opacity: 1 })
      await nextTick()
      mockBridge.reset()

      // Same value — should not re-send
      nodeOps.patchProp(el, 'style', { opacity: 1 }, { opacity: 1 })
      await nextTick()

      expect(mockBridge.getOpsByType('updateStyle')).toHaveLength(0)
    })
  })

  // -------------------------------------------------------------------------
  // patchProp — events
  // -------------------------------------------------------------------------
  describe('patchProp: events', () => {
    it('routes onPress to addEventListener with event name "press"', async () => {
      const el = nodeOps.createElement('VButton')
      await nextTick()
      mockBridge.reset()

      nodeOps.patchProp(el, 'onPress', null, () => {})
      await nextTick()

      const ops = mockBridge.getOpsByType('addEventListener')
      expect(ops).toHaveLength(1)
      expect(ops[0].args[1]).toBe('press')
    })

    it('removes old listener before adding new one when handler changes', async () => {
      const el = nodeOps.createElement('VButton')
      const handler1 = () => {}
      const handler2 = () => {}
      nodeOps.patchProp(el, 'onPress', null, handler1)
      await nextTick()
      mockBridge.reset()

      nodeOps.patchProp(el, 'onPress', handler1, handler2)
      await nextTick()

      const addOps = mockBridge.getOpsByType('addEventListener')
      const removeOps = mockBridge.getOpsByType('removeEventListener')
      expect(addOps).toHaveLength(1)
      expect(removeOps).toHaveLength(1)
    })

    it('removes listener when next value is null', async () => {
      const el = nodeOps.createElement('VButton')
      nodeOps.patchProp(el, 'onPress', null, () => {})
      await nextTick()
      mockBridge.reset()

      nodeOps.patchProp(el, 'onPress', () => {}, null)
      await nextTick()

      expect(mockBridge.getOpsByType('removeEventListener')).toHaveLength(1)
      expect(mockBridge.getOpsByType('addEventListener')).toHaveLength(0)
    })

    it('does not treat non-handler "on*" strings as events', async () => {
      // "onFoo" where "F" is uppercase is an event; but plain props are not
      const el = nodeOps.createElement('VView')
      await nextTick()
      mockBridge.reset()

      // This is a regular prop, NOT an event handler
      nodeOps.patchProp(el, 'value', null, 'hello')
      await nextTick()

      expect(mockBridge.getOpsByType('addEventListener')).toHaveLength(0)
      expect(mockBridge.getOpsByType('updateProp')).toHaveLength(1)
    })
  })

  // -------------------------------------------------------------------------
  // patchProp — regular props
  // -------------------------------------------------------------------------
  describe('patchProp: regular props', () => {
    it('sends updateProp for non-style, non-event keys', async () => {
      const el = nodeOps.createElement('VInput')
      await nextTick()
      mockBridge.reset()

      nodeOps.patchProp(el, 'placeholder', null, 'Enter text')
      await nextTick()

      const ops = mockBridge.getOpsByType('updateProp')
      expect(ops[0].args).toEqual([el.id, 'placeholder', 'Enter text'])
    })
  })

  // -------------------------------------------------------------------------
  // insert
  // -------------------------------------------------------------------------
  describe('insert', () => {
    it('appends child when anchor is null', async () => {
      const parent = nodeOps.createElement('VView')
      const child = nodeOps.createElement('VText')
      await nextTick()
      mockBridge.reset()

      nodeOps.insert(child, parent, null)
      expect(parent.children).toContain(child)
      expect(child.parent).toBe(parent)
      await nextTick()

      const ops = mockBridge.getOpsByType('appendChild')
      expect(ops[0].args).toEqual([parent.id, child.id])
    })

    it('inserts before anchor when anchor is provided', async () => {
      const parent = nodeOps.createElement('VView')
      const child1 = nodeOps.createElement('VText')
      const child2 = nodeOps.createElement('VText')
      nodeOps.insert(child1, parent, null)
      await nextTick()
      mockBridge.reset()

      nodeOps.insert(child2, parent, child1)
      expect(parent.children.indexOf(child2)).toBeLessThan(parent.children.indexOf(child1))
      await nextTick()

      const ops = mockBridge.getOpsByType('insertBefore')
      expect(ops[0].args).toEqual([parent.id, child2.id, child1.id])
    })

    it('does NOT send bridge op for comment nodes', async () => {
      const parent = nodeOps.createElement('VView')
      const comment = nodeOps.createComment('v-if')
      await nextTick()
      mockBridge.reset()

      nodeOps.insert(comment, parent, null)
      await nextTick()

      // No appendChild for comment nodes
      expect(mockBridge.getOpsByType('appendChild')).toHaveLength(0)
      // But the comment IS in the JS children array
      expect(parent.children).toContain(comment)
    })

    it('re-parents a child from its previous parent', async () => {
      const parent1 = nodeOps.createElement('VView')
      const parent2 = nodeOps.createElement('VView')
      const child = nodeOps.createElement('VText')
      nodeOps.insert(child, parent1, null)
      await nextTick()
      mockBridge.reset()

      nodeOps.insert(child, parent2, null)
      expect(parent1.children).not.toContain(child)
      expect(parent2.children).toContain(child)
      expect(child.parent).toBe(parent2)
    })
  })

  // -------------------------------------------------------------------------
  // remove
  // -------------------------------------------------------------------------
  describe('remove', () => {
    it('removes child from parent JS tree and sends removeChild op', async () => {
      const parent = nodeOps.createElement('VView')
      const child = nodeOps.createElement('VText')
      nodeOps.insert(child, parent, null)
      await nextTick()
      mockBridge.reset()

      nodeOps.remove(child)
      expect(parent.children).not.toContain(child)
      expect(child.parent).toBeNull()
      await nextTick()

      const ops = mockBridge.getOpsByType('removeChild')
      expect(ops[0].args).toEqual([child.id])
    })

    it('does NOT send removeChild for comment nodes', async () => {
      const parent = nodeOps.createElement('VView')
      const comment = nodeOps.createComment('v-if')
      nodeOps.insert(comment, parent, null)
      await nextTick()
      mockBridge.reset()

      nodeOps.remove(comment)
      await nextTick()

      expect(mockBridge.getOpsByType('removeChild')).toHaveLength(0)
    })
  })

  // -------------------------------------------------------------------------
  // parentNode / nextSibling
  // -------------------------------------------------------------------------
  describe('parentNode', () => {
    it('returns the parent of a node', () => {
      const parent = nodeOps.createElement('VView')
      const child = nodeOps.createElement('VText')
      nodeOps.insert(child, parent, null)
      expect(nodeOps.parentNode(child)).toBe(parent)
    })

    it('returns null for a node with no parent', () => {
      const node = nodeOps.createElement('VView')
      expect(nodeOps.parentNode(node)).toBeNull()
    })
  })

  describe('nextSibling', () => {
    it('returns the next sibling in parent.children', () => {
      const parent = nodeOps.createElement('VView')
      const child1 = nodeOps.createElement('VText')
      const child2 = nodeOps.createElement('VText')
      nodeOps.insert(child1, parent, null)
      nodeOps.insert(child2, parent, null)
      expect(nodeOps.nextSibling(child1)).toBe(child2)
    })

    it('returns null for the last child', () => {
      const parent = nodeOps.createElement('VView')
      const child = nodeOps.createElement('VText')
      nodeOps.insert(child, parent, null)
      expect(nodeOps.nextSibling(child)).toBeNull()
    })

    it('returns null for a node with no parent', () => {
      const node = nodeOps.createElement('VView')
      expect(nodeOps.nextSibling(node)).toBeNull()
    })
  })
})
