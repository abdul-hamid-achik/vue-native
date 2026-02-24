/**
 * StyleSheet tests — verifies createStyleSheet validation, freezing, and
 * the validStyleProperties set.
 */
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { installMockBridge } from './helpers'

installMockBridge()

const { createStyleSheet, validStyleProperties } = await import('../stylesheet')

describe('createStyleSheet', () => {
  beforeEach(() => {
    vi.restoreAllMocks()
  })

  it('returns an object with frozen style entries', () => {
    const styles = createStyleSheet({
      container: { flex: 1, backgroundColor: '#fff' },
      title: { fontSize: 24 },
    })

    expect(styles.container.flex).toBe(1)
    expect(styles.container.backgroundColor).toBe('#fff')
    expect(styles.title.fontSize).toBe(24)
    expect(Object.isFrozen(styles)).toBe(true)
    expect(Object.isFrozen(styles.container)).toBe(true)
    expect(Object.isFrozen(styles.title)).toBe(true)
  })

  it('prevents mutation of returned styles', () => {
    const styles = createStyleSheet({
      box: { flex: 1 },
    })

    expect(() => {
      ;(styles.box as any).flex = 2
    }).toThrow()
  })

  it('freezes the outer object', () => {
    const styles = createStyleSheet({
      a: { flex: 1 },
    })

    expect(() => {
      ;(styles as any).b = { flex: 2 }
    }).toThrow()
  })

  it('warns about unknown style properties in dev mode', () => {
    const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {})

    createStyleSheet({
      bad: { unknownProp: 'value' } as any,
    })

    expect(warnSpy).toHaveBeenCalledWith(
      expect.stringContaining('Unknown style property "unknownProp"'),
    )
  })

  it('does not warn for valid style properties', () => {
    const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {})

    createStyleSheet({
      valid: {
        flex: 1,
        backgroundColor: '#000',
        padding: 16,
        fontSize: 14,
        borderRadius: 8,
        opacity: 0.5,
      },
    })

    expect(warnSpy).not.toHaveBeenCalled()
  })

  it('preserves all properties from input', () => {
    const input = {
      row: {
        flexDirection: 'row' as const,
        alignItems: 'center' as const,
        gap: 8,
      },
    }
    const styles = createStyleSheet(input)
    expect(styles.row.flexDirection).toBe('row')
    expect(styles.row.alignItems).toBe('center')
    expect(styles.row.gap).toBe(8)
  })

  it('does not mutate the original input', () => {
    const input = {
      box: { flex: 1, padding: 10 },
    }
    createStyleSheet(input)
    // Input should still be mutable
    input.box.flex = 2
    expect(input.box.flex).toBe(2)
  })

  it('handles multiple style entries', () => {
    const styles = createStyleSheet({
      a: { flex: 1 },
      b: { flex: 2 },
      c: { flex: 3 },
    })
    expect(Object.keys(styles)).toEqual(['a', 'b', 'c'])
    expect(styles.a.flex).toBe(1)
    expect(styles.b.flex).toBe(2)
    expect(styles.c.flex).toBe(3)
  })

  it('handles empty styles', () => {
    const styles = createStyleSheet({})
    expect(Object.keys(styles)).toHaveLength(0)
    expect(Object.isFrozen(styles)).toBe(true)
  })
})

describe('validStyleProperties', () => {
  it('contains core layout properties', () => {
    const layoutProps = [
      'flex', 'flexDirection', 'flexWrap', 'flexGrow', 'flexShrink', 'flexBasis',
      'justifyContent', 'alignItems', 'alignSelf', 'alignContent',
      'width', 'height', 'minWidth', 'minHeight', 'maxWidth', 'maxHeight',
      'margin', 'marginTop', 'marginRight', 'marginBottom', 'marginLeft',
      'padding', 'paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft',
      'position', 'top', 'right', 'bottom', 'left',
    ]
    for (const prop of layoutProps) {
      expect(validStyleProperties.has(prop)).toBe(true)
    }
  })

  it('contains visual properties', () => {
    expect(validStyleProperties.has('backgroundColor')).toBe(true)
    expect(validStyleProperties.has('opacity')).toBe(true)
  })

  it('contains border properties', () => {
    const borderProps = [
      'borderWidth', 'borderColor', 'borderRadius', 'borderStyle',
      'borderTopWidth', 'borderRightWidth', 'borderBottomWidth', 'borderLeftWidth',
    ]
    for (const prop of borderProps) {
      expect(validStyleProperties.has(prop)).toBe(true)
    }
  })

  it('contains text properties', () => {
    const textProps = [
      'color', 'fontSize', 'fontWeight', 'fontFamily', 'fontStyle',
      'lineHeight', 'letterSpacing', 'textAlign', 'textTransform',
    ]
    for (const prop of textProps) {
      expect(validStyleProperties.has(prop)).toBe(true)
    }
  })

  it('contains shadow properties', () => {
    expect(validStyleProperties.has('shadowColor')).toBe(true)
    expect(validStyleProperties.has('shadowOffset')).toBe(true)
    expect(validStyleProperties.has('shadowOpacity')).toBe(true)
    expect(validStyleProperties.has('shadowRadius')).toBe(true)
  })

  it('contains accessibility properties', () => {
    const a11yProps = [
      'accessibilityLabel', 'accessibilityRole', 'accessibilityHint',
      'accessibilityState', 'accessibilityValue', 'accessible',
      'importantForAccessibility',
    ]
    for (const prop of a11yProps) {
      expect(validStyleProperties.has(prop)).toBe(true)
    }
  })

  it('contains image properties', () => {
    expect(validStyleProperties.has('resizeMode')).toBe(true)
    expect(validStyleProperties.has('tintColor')).toBe(true)
  })

  it('contains transform property', () => {
    expect(validStyleProperties.has('transform')).toBe(true)
  })

  it('does not contain arbitrary names', () => {
    expect(validStyleProperties.has('banana')).toBe(false)
    expect(validStyleProperties.has('webkitTransform')).toBe(false)
    expect(validStyleProperties.has('className')).toBe(false)
  })
})
