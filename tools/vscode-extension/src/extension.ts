import * as vscode from 'vscode'
import { scanForDiagnostics, type DiagnosticSeverityLevel } from './diagnostics'

const SEVERITY_MAP: Record<DiagnosticSeverityLevel, vscode.DiagnosticSeverity> = {
  error: vscode.DiagnosticSeverity.Error,
  hint: vscode.DiagnosticSeverity.Hint,
}

export function activate(context: vscode.ExtensionContext) {
  // Diagnostics: warn on common Vue Native mistakes in .vue files
  const diagnosticCollection = vscode.languages.createDiagnosticCollection('vue-native')
  context.subscriptions.push(diagnosticCollection)

  function updateDiagnostics(document: vscode.TextDocument) {
    if (document.languageId !== 'vue') return

    const diagnostics = scanForDiagnostics(document.getText()).map((match) => {
      const diagnostic = new vscode.Diagnostic(
        new vscode.Range(document.positionAt(match.start), document.positionAt(match.end)),
        match.message,
        SEVERITY_MAP[match.severity],
      )
      diagnostic.source = 'Vue Native'
      return diagnostic
    })

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
