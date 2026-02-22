import { describe, it, expect, vi, beforeEach } from 'vitest'
import { createStyleSheet, validStyleProperties } from '../stylesheet'

describe('createStyleSheet', () => {
  beforeEach(() => {
    vi.restoreAllMocks()
  })

  it('returns frozen style objects', () => {
    const styles = createStyleSheet({
      container: { flex: 1, backgroundColor: '#fff' },
    })

    expect(Object.isFrozen(styles)).toBe(true)
    expect(Object.isFrozen(styles.container)).toBe(true)
  })

  it('preserves all valid style properties', () => {
    const styles = createStyleSheet({
      box: {
        flex: 1,
        flexDirection: 'row',
        justifyContent: 'center',
        alignItems: 'center',
        backgroundColor: '#000',
        padding: 16,
        margin: 8,
        borderRadius: 4,
      },
    })

    expect(styles.box.flex).toBe(1)
    expect(styles.box.flexDirection).toBe('row')
    expect(styles.box.justifyContent).toBe('center')
    expect(styles.box.padding).toBe(16)
  })

  it('warns on unknown style properties in dev mode', () => {
    const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {})

    createStyleSheet({
      invalid: { invalidProp: 'value' } as any,
    })

    expect(warnSpy).toHaveBeenCalledWith(
      expect.stringContaining('Unknown style property "invalidProp"')
    )
  })

  it('supports multiple named styles', () => {
    const styles = createStyleSheet({
      container: { flex: 1 },
      title: { fontSize: 24, fontWeight: 'bold' },
      subtitle: { fontSize: 16, color: '#666' },
    })

    expect(styles.container.flex).toBe(1)
    expect(styles.title.fontSize).toBe(24)
    expect(styles.subtitle.color).toBe('#666')
  })

  it('does not share references with input', () => {
    const input = { flex: 1 }
    const styles = createStyleSheet({ box: input })

    // Modifying input should not affect styles (they are copies)
    input.flex = 2
    expect(styles.box.flex).toBe(1)
  })
})

describe('validStyleProperties', () => {
  it('contains layout properties', () => {
    expect(validStyleProperties.has('flex')).toBe(true)
    expect(validStyleProperties.has('flexDirection')).toBe(true)
    expect(validStyleProperties.has('justifyContent')).toBe(true)
    expect(validStyleProperties.has('alignItems')).toBe(true)
    expect(validStyleProperties.has('position')).toBe(true)
  })

  it('contains visual properties', () => {
    expect(validStyleProperties.has('backgroundColor')).toBe(true)
    expect(validStyleProperties.has('opacity')).toBe(true)
    expect(validStyleProperties.has('borderRadius')).toBe(true)
  })

  it('contains text properties', () => {
    expect(validStyleProperties.has('fontSize')).toBe(true)
    expect(validStyleProperties.has('fontWeight')).toBe(true)
    expect(validStyleProperties.has('color')).toBe(true)
    expect(validStyleProperties.has('textAlign')).toBe(true)
  })

  it('does not contain invalid properties', () => {
    expect(validStyleProperties.has('invalid')).toBe(false)
    expect(validStyleProperties.has('className')).toBe(false)
    expect(validStyleProperties.has('float')).toBe(false)
  })
})
