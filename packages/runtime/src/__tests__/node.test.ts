import { describe, it, expect, beforeEach } from 'vitest'
import { installMockBridge } from './helpers'

// Install mock bridge so imports that touch globalThis don't warn
installMockBridge()

const { createNativeNode, createTextNode, createCommentNode, resetNodeId } = await import('../node')

describe('NativeNode', () => {

  beforeEach(() => {
    resetNodeId()
  })

  describe('createNativeNode', () => {
    it('has the correct shape', () => {
      const node = createNativeNode('VView')
      expect(node).toMatchObject({
        type: 'VView',
        props: {},
        children: [],
        parent: null,
        isText: false,
      })
    })

    it('assigns a positive numeric id', () => {
      const node = createNativeNode('VView')
      expect(typeof node.id).toBe('number')
      expect(node.id).toBeGreaterThan(0)
    })

    it('id starts at 1 after resetNodeId', () => {
      const node = createNativeNode('VView')
      expect(node.id).toBe(1)
    })

    it('each node gets a unique id', () => {
      const ids = new Set(Array.from({ length: 100 }, () => createNativeNode('VView').id))
      expect(ids.size).toBe(100)
    })

    it('node is marked raw (not reactive)', () => {
      const node = createNativeNode('VText')
      // markRaw sets __v_skip = true on the object
      expect((node as any).__v_skip).toBe(true)
    })

    it('has isText = false', () => {
      const node = createNativeNode('VView')
      expect(node.isText).toBe(false)
    })

    it('initializes with empty children array', () => {
      const node = createNativeNode('VView')
      expect(node.children).toEqual([])
    })
  })

  describe('createTextNode', () => {
    it('has __TEXT__ type', () => {
      const node = createTextNode('hello')
      expect(node.type).toBe('__TEXT__')
    })

    it('stores text content', () => {
      const node = createTextNode('hello world')
      expect(node.text).toBe('hello world')
    })

    it('has isText = true', () => {
      const node = createTextNode('hi')
      expect(node.isText).toBe(true)
    })

    it('is marked raw', () => {
      const node = createTextNode('hi')
      expect((node as any).__v_skip).toBe(true)
    })

    it('gets a unique id distinct from element nodes', () => {
      const el = createNativeNode('VView')
      const text = createTextNode('hi')
      expect(el.id).not.toBe(text.id)
    })
  })

  describe('createCommentNode', () => {
    it('has __COMMENT__ type', () => {
      const node = createCommentNode('v-if')
      expect(node.type).toBe('__COMMENT__')
    })

    it('is marked raw', () => {
      const node = createCommentNode('v-if')
      expect((node as any).__v_skip).toBe(true)
    })

    it('has isText = false', () => {
      const node = createCommentNode('v-if')
      expect(node.isText).toBe(false)
    })
  })

  describe('id uniqueness across node types', () => {
    it('ids are globally unique across createNativeNode, createTextNode, createCommentNode', () => {
      const ids = [
        createNativeNode('VView').id,
        createTextNode('hi').id,
        createCommentNode('v-if').id,
        createNativeNode('VButton').id,
        createTextNode('world').id,
      ]
      expect(new Set(ids).size).toBe(ids.length)
    })
  })
})
