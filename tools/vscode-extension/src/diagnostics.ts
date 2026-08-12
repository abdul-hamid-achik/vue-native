/**
 * Diagnostic rules for common Vue Native mistakes in .vue files.
 *
 * Kept free of any 'vscode' import so the scanning logic is unit-testable;
 * extension.ts maps these results onto the VS Code diagnostics API.
 */

export type DiagnosticSeverityLevel = 'error' | 'hint'

export interface DiagnosticRule {
  pattern: RegExp
  message: string
  severity: DiagnosticSeverityLevel
}

export interface DiagnosticMatch {
  /** Start offset of the match in the document text. */
  start: number
  /** End offset (exclusive) of the match in the document text. */
  end: number
  message: string
  severity: DiagnosticSeverityLevel
}

export const DIAGNOSTIC_RULES: DiagnosticRule[] = [
  {
    pattern: /\bapp\.mount\s*\(/g,
    message: 'Vue Native uses app.start() instead of app.mount(). There is no DOM to mount to.',
    severity: 'error',
  },
  {
    pattern: /import\s+.*from\s+['"]vue['"]/g,
    message: 'In Vue Native, import from "@thelacanians/vue-native-runtime" instead of "vue" for runtime APIs. The Vite plugin aliases "vue" automatically, but explicit imports are clearer.',
    severity: 'hint',
  },
]

export function scanForDiagnostics(text: string): DiagnosticMatch[] {
  const matches: DiagnosticMatch[] = []

  for (const rule of DIAGNOSTIC_RULES) {
    rule.pattern.lastIndex = 0
    let match: RegExpExecArray | null
    while ((match = rule.pattern.exec(text)) !== null) {
      matches.push({
        start: match.index,
        end: match.index + match[0].length,
        message: rule.message,
        severity: rule.severity,
      })
    }
  }

  return matches
}
