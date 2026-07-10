import type { NativeBlock, ParseError } from '@thelacanians/vue-native-sfc-parser'

/**
 * Validation result with errors and warnings
 */
export interface ValidationResult {
  errors: ParseError[]
  warnings: ParseError[]
  isValid: boolean
}

/**
 * Validate native blocks for syntax and consistency
 */
export function validateNativeBlocks(blocks: NativeBlock[]): ValidationResult {
  const errors: ParseError[] = []
  const warnings: ParseError[] = []

  for (const block of blocks) {
    // Validate Swift syntax (basic)
    if (block.language === 'swift') {
      const swiftErrors = validateSwiftSyntax(block)
      errors.push(...swiftErrors)
    }

    // Validate Kotlin syntax (basic)
    if (block.language === 'kotlin') {
      const kotlinValidation = validateKotlinSyntax(block)
      errors.push(...kotlinValidation.errors)
      warnings.push(...kotlinValidation.warnings)
    }

    // Validate NativeModule implementation
    const moduleErrors = validateNativeModuleStructure(block)
    errors.push(...moduleErrors)

    // Validate method signatures
    const methodWarnings = validateMethodSignatures(block)
    warnings.push(...methodWarnings)
  }

  // Validate cross-platform consistency
  const collisionErrors = validateOutputCollisions(blocks)
  errors.push(...collisionErrors)

  const consistencyWarnings = validateCrossPlatformConsistency(blocks)
  warnings.push(...consistencyWarnings)

  return {
    errors,
    warnings,
    isValid: errors.length === 0,
  }
}

/**
 * Validate Swift syntax (basic checks)
 */
function validateSwiftSyntax(block: NativeBlock): ParseError[] {
  const errors: ParseError[] = []
  const { content, sourceFile } = block

  // Check for class declaration
  if (!content.match(/class\s+\w+\s*:\s*NativeModule/)) {
    errors.push({
      file: sourceFile,
      line: block.startLine,
      message: 'Swift code must declare a class that conforms to NativeModule protocol',
    })
  }

  // Check for moduleName property
  if (!content.match(/var\s+moduleName\s*:\s*String\s*\{/)) {
    errors.push({
      file: sourceFile,
      line: block.startLine,
      message: 'Swift module must declare `var moduleName: String { "ModuleName" }`',
    })
  }

  // Check for invoke method
  if (!content.match(/func\s+invoke\s*\([^)]*method[^)]*String[^)]*\)/)) {
    errors.push({
      file: sourceFile,
      line: block.startLine,
      message: 'Swift module must implement `invoke(method:args:callback:)` method',
    })
  }

  // Check for balanced braces
  const openBraces = (content.match(/{/g) || []).length
  const closeBraces = (content.match(/}/g) || []).length
  if (openBraces !== closeBraces) {
    errors.push({
      file: sourceFile,
      line: block.startLine,
      message: `Unbalanced braces: ${openBraces} opening, ${closeBraces} closing`,
    })
  }

  // Check for balanced parentheses
  const openParens = (content.match(/\(/g) || []).length
  const closeParens = (content.match(/\)/g) || []).length
  if (openParens !== closeParens) {
    errors.push({
      file: sourceFile,
      line: block.startLine,
      message: `Unbalanced parentheses: ${openParens} opening, ${closeParens} closing`,
    })
  }

  return errors
}

/**
 * Validate Kotlin syntax (basic checks)
 */
function validateKotlinSyntax(block: NativeBlock): Pick<ValidationResult, 'errors' | 'warnings'> {
  const errors: ParseError[] = []
  const warnings: ParseError[] = []
  const { content, sourceFile } = block

  // Check for class declaration
  if (!content.match(/class\s+\w+\s*:\s*NativeModule/)) {
    errors.push({
      file: sourceFile,
      line: block.startLine,
      message: 'Kotlin code must declare a class that implements NativeModule interface',
    })
  }

  // Check for moduleName property
  if (!content.match(/override\s+val\s+moduleName\s*:\s*String\s*=/)) {
    errors.push({
      file: sourceFile,
      line: block.startLine,
      message: 'Kotlin module must declare `override val moduleName: String = "ModuleName"`',
    })
  }

  // Check for invoke method (more flexible pattern)
  if (!content.match(/(?:override\s+)?fun\s+invoke\s*\(/)) {
    errors.push({
      file: sourceFile,
      line: block.startLine,
      message: 'Kotlin module must implement `invoke(method:args:callback)` method',
    })
  } else if (!content.match(/(?:override\s+)?fun\s+invoke\s*\([^)]*\bbridge\s*:\s*NativeBridge[^)]*\)/s)) {
    errors.push({
      file: sourceFile,
      line: block.startLine,
      message: 'Kotlin invoke method must include `bridge: NativeBridge` to match the NativeModule interface',
    })
  }

  // Check for balanced braces
  const openBraces = (content.match(/{/g) || []).length
  const closeBraces = (content.match(/}/g) || []).length
  if (openBraces !== closeBraces) {
    errors.push({
      file: sourceFile,
      line: block.startLine,
      message: `Unbalanced braces: ${openBraces} opening, ${closeBraces} closing`,
    })
  }

  // Note: Skipping parenthesis balance check for Kotlin due to complex lambda syntax

  // Check for common Kotlin issues
  if (content.includes('List<Any>') && !content.includes('List<Any?>')) {
    warnings.push({
      file: sourceFile,
      line: block.startLine,
      message: 'Consider using List<Any?> for nullable arguments',
    })
  }

  return { errors, warnings }
}

/**
 * Validate NativeModule structure
 */
function validateNativeModuleStructure(block: NativeBlock): ParseError[] {
  const errors: ParseError[] = []
  const { content, sourceFile } = block

  // Check for NativeModule conformance/implementation
  if (block.language === 'swift' && !content.includes(': NativeModule')) {
    errors.push({
      file: sourceFile,
      line: block.startLine,
      message: 'Class must conform to NativeModule protocol',
    })
  }

  if (block.language === 'kotlin' && !content.includes(': NativeModule')) {
    errors.push({
      file: sourceFile,
      line: block.startLine,
      message: 'Class must implement NativeModule interface',
    })
  }

  // Check for callback handling
  if (!content.includes('callback(')) {
    errors.push({
      file: sourceFile,
      line: block.startLine,
      message: 'Module must call callback with result or error',
    })
  }

  return errors
}

/**
 * Validate method signatures and provide warnings
 */
function validateMethodSignatures(block: NativeBlock): ParseError[] {
  const warnings: ParseError[] = []
  const { content, sourceFile } = block

  // Check for methods without error handling
  const methods = extractMethodNames(block)
  for (const method of methods) {
    if (method !== 'invoke' && method !== 'invokeSync') {
      // Check if method has try-catch or error handling
      if (block.language === 'swift' && !content.includes('do {') && !content.includes('try?')) {
        warnings.push({
          file: sourceFile,
          line: block.startLine,
          message: `Method '${method}' should have error handling (do-catch or try?)`,
        })
      }
    }
  }

  return warnings
}

/**
 * Extract method names from native code
 */
function extractMethodNames(block: NativeBlock): string[] {
  const methods: string[] = []
  const { content, language } = block

  if (language === 'swift') {
    const matches = content.matchAll(/func\s+(\w+)\s*\(/g)
    for (const match of matches) {
      methods.push(match[1])
    }
  } else if (language === 'kotlin') {
    const matches = content.matchAll(/(?:override\s+)?fun\s+(\w+)\s*\(/g)
    for (const match of matches) {
      methods.push(match[1])
    }
  }

  return methods
}

/**
 * Validate cross-platform consistency
 */
function validateCrossPlatformConsistency(blocks: NativeBlock[]): ParseError[] {
  const warnings: ParseError[] = []

  // Match implementations by SFC and native class. One SFC may intentionally
  // define several unrelated modules, so grouping only by component name
  // produces false cross-platform mismatch warnings.
  const byImplementation = new Map<string, NativeBlock[]>()
  for (const block of blocks) {
    const className = extractClassName(block.content) ?? '<unknown>'
    const key = `${block.componentName}:${className}`
    const existing = byImplementation.get(key) || []
    existing.push(block)
    byImplementation.set(key, existing)
  }

  // Check matching class implementations use the same runtime module name.
  for (const implementationBlocks of byImplementation.values()) {
    const platforms = new Set(implementationBlocks.map(block => block.platform))
    if (platforms.size > 1) {
      const moduleNames = new Set(
        implementationBlocks.map(block => extractModuleName(block.content)),
      )

      if (moduleNames.size > 1) {
        warnings.push({
          file: implementationBlocks[0].sourceFile,
          line: implementationBlocks[0].startLine,
          message: `Native class '${extractClassName(implementationBlocks[0].content) ?? 'unknown'}' has different module names across platforms: ${Array.from(moduleNames).join(', ')}`,
        })
      }
    }
  }

  return warnings
}

/**
 * Reject output and registry collisions before generation. Two classes with
 * the same platform/class name overwrite the same generated source file, and
 * two modules with the same platform/moduleName silently overwrite one entry
 * in NativeModuleRegistry.
 */
function validateOutputCollisions(blocks: NativeBlock[]): ParseError[] {
  const errors: ParseError[] = []
  const classes = new Map<string, NativeBlock>()
  const modules = new Map<string, NativeBlock>()

  for (const block of blocks) {
    const className = extractClassName(block.content)
    if (className) {
      const classKey = `${block.platform}:${className}`
      const existingClass = classes.get(classKey)
      if (existingClass) {
        errors.push({
          file: block.sourceFile,
          line: block.startLine,
          message: `Duplicate ${block.platform} native class '${className}' would overwrite generated output from ${existingClass.sourceFile}`,
        })
      } else {
        classes.set(classKey, block)
      }
    }

    const moduleName = extractModuleName(block.content)
    if (moduleName !== 'Unknown') {
      const moduleKey = `${block.platform}:${moduleName}`
      const existingModule = modules.get(moduleKey)
      if (existingModule) {
        errors.push({
          file: block.sourceFile,
          line: block.startLine,
          message: `Duplicate ${block.platform} module name '${moduleName}' would overwrite the native registry entry from ${existingModule.sourceFile}`,
        })
      } else {
        modules.set(moduleKey, block)
      }
    }
  }

  return errors
}

function extractClassName(content: string): string | undefined {
  return content.match(/class\s+(\w+)\s*:/)?.[1]
}

/**
 * Extract module name from native code
 */
function extractModuleName(content: string): string {
  // Swift pattern
  const swiftMatch = content.match(/var\s+moduleName\s*:\s*String\s*\{\s*"([^"]+)"\s*\}/)
  if (swiftMatch) return swiftMatch[1]

  // Kotlin pattern
  const kotlinMatch = content.match(/override\s+val\s+moduleName\s*:\s*String\s*=\s*"([^"]+)"/)
  if (kotlinMatch) return kotlinMatch[1]

  return 'Unknown'
}

/**
 * Format validation errors for display
 */
export function formatValidationErrors(result: ValidationResult): string {
  const lines: string[] = []

  if (result.errors.length > 0) {
    lines.push('\n❌ Errors:')
    for (const error of result.errors) {
      lines.push(`  ${formatErrorLocation(error)} ${error.message}`)
    }
  }

  if (result.warnings.length > 0) {
    lines.push('\n⚠️  Warnings:')
    for (const warning of result.warnings) {
      lines.push(`  ${formatErrorLocation(warning)} ${warning.message}`)
    }
  }

  return lines.join('\n')
}

/**
 * Format error location
 */
function formatErrorLocation(error: ParseError): string {
  const file = error.file.split('/').pop() || error.file
  const line = error.line || '?'
  return `${file}:${line}`
}

/**
 * Get diagnostic information for a native block
 */
export function getDiagnostics(block: NativeBlock): {
  methodCount: number
  hasErrorHandling: boolean
  complexity: 'low' | 'medium' | 'high'
  suggestions: string[]
} {
  const methods = extractMethodNames(block)
  const hasTryCatch = block.content.includes('try ') || block.content.includes('try?')
  const hasCatch = block.content.includes('catch') || block.content.includes('runCatching')

  // Calculate complexity based on lines and nesting
  const lines = block.content.split('\n').length
  const nestingDepth = (block.content.match(/{/g) || []).length

  let complexity: 'low' | 'medium' | 'high' = 'low'
  if (lines > 50 || nestingDepth > 3) {
    complexity = 'high'
  } else if (lines > 20 || nestingDepth > 2) {
    complexity = 'medium'
  }

  const suggestions: string[] = []

  if (!hasTryCatch && methods.length > 0) {
    suggestions.push('Add error handling (try-catch or runCatching)')
  }

  if (complexity === 'high') {
    suggestions.push('Consider splitting into smaller methods')
  }

  if (methods.length === 1 && methods[0] === 'invoke') {
    suggestions.push('Add helper methods for better code organization')
  }

  return {
    methodCount: methods.filter(m => m !== 'invoke' && m !== 'invokeSync').length,
    hasErrorHandling: hasCatch,
    complexity,
    suggestions,
  }
}
