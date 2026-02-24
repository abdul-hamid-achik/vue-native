import * as vscode from 'vscode'

export function activate(context: vscode.ExtensionContext) {
  // Diagnostics: warn on common Vue Native mistakes in .vue files
  const diagnosticCollection = vscode.languages.createDiagnosticCollection('vue-native')
  context.subscriptions.push(diagnosticCollection)

  const DIAGNOSTIC_RULES: Array<{
    pattern: RegExp
    message: string
    severity: vscode.DiagnosticSeverity
  }> = [
    {
      pattern: /\bapp\.mount\s*\(/g,
      message: 'Vue Native uses app.start() instead of app.mount(). There is no DOM to mount to.',
      severity: vscode.DiagnosticSeverity.Error,
    },
    {
      pattern: /@press\b/g,
      message: 'Vue Native buttons use :onPress (prop binding), not @press (event). Use :onPress="handler".',
      severity: vscode.DiagnosticSeverity.Warning,
    },
    {
      pattern: /import\s+.*from\s+['"]vue['"]/g,
      message: 'In Vue Native, import from "@thelacanians/vue-native-runtime" instead of "vue" for runtime APIs. The Vite plugin aliases "vue" automatically, but explicit imports are clearer.',
      severity: vscode.DiagnosticSeverity.Hint,
    },
  ]

  function updateDiagnostics(document: vscode.TextDocument) {
    if (document.languageId !== 'vue') return

    const diagnostics: vscode.Diagnostic[] = []
    const text = document.getText()

    for (const rule of DIAGNOSTIC_RULES) {
      rule.pattern.lastIndex = 0
      let match: RegExpExecArray | null
      while ((match = rule.pattern.exec(text)) !== null) {
        const startPos = document.positionAt(match.index)
        const endPos = document.positionAt(match.index + match[0].length)
        const diagnostic = new vscode.Diagnostic(
          new vscode.Range(startPos, endPos),
          rule.message,
          rule.severity,
        )
        diagnostic.source = 'Vue Native'
        diagnostics.push(diagnostic)
      }
    }

    diagnosticCollection.set(document.uri, diagnostics)
  }

  // Run diagnostics on open and change
  if (vscode.window.activeTextEditor) {
    updateDiagnostics(vscode.window.activeTextEditor.document)
  }

  context.subscriptions.push(
    vscode.window.onDidChangeActiveTextEditor((editor) => {
      if (editor) updateDiagnostics(editor.document)
    }),
  )

  context.subscriptions.push(
    vscode.workspace.onDidChangeTextDocument((event) => {
      updateDiagnostics(event.document)
    }),
  )

  context.subscriptions.push(
    vscode.workspace.onDidCloseTextDocument((document) => {
      diagnosticCollection.delete(document.uri)
    }),
  )
}

export function deactivate() {}
