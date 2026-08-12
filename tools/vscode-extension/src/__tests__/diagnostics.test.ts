import { describe, it, expect } from 'vitest'
import { scanForDiagnostics } from '../diagnostics'

describe('scanForDiagnostics', () => {
  it('flags app.mount() as an error', () => {
    const text = `const app = createApp(App)\napp.mount('#app')\n`
    const matches = scanForDiagnostics(text)

    expect(matches).toHaveLength(1)
    expect(matches[0].severity).toBe('error')
    expect(matches[0].message).toContain('app.start()')
    expect(text.slice(matches[0].start, matches[0].end)).toBe('app.mount(')
  })

  it('flags every occurrence, not just the first', () => {
    const text = `app.mount('#a')\napp.mount('#b')\n`
    expect(scanForDiagnostics(text)).toHaveLength(2)
  })

  it('hints on imports from "vue"', () => {
    const text = `import { ref } from 'vue'\n`
    const matches = scanForDiagnostics(text)

    expect(matches).toHaveLength(1)
    expect(matches[0].severity).toBe('hint')
    expect(matches[0].message).toContain('@thelacanians/vue-native-runtime')
  })

  it('matches double-quoted vue imports', () => {
    expect(scanForDiagnostics('import { ref } from "vue"\n')).toHaveLength(1)
  })

  it('does not flag imports from the runtime package or app.start()', () => {
    const text = [
      `import { createApp } from '@thelacanians/vue-native-runtime'`,
      `const app = createApp(App)`,
      `app.start()`,
    ].join('\n')

    expect(scanForDiagnostics(text)).toEqual([])
  })

  it('does not flag unrelated mount identifiers', () => {
    expect(scanForDiagnostics('remount(node)\nconst mount = 1\n')).toEqual([])
  })

  it('is stateful-regex safe: repeated scans return identical results', () => {
    const text = `app.mount('#app')\n`
    expect(scanForDiagnostics(text)).toEqual(scanForDiagnostics(text))
  })
})
