import type { NativeBlock } from '@thelacanians/vue-native-sfc-parser'
import type { GeneratedFile, CodegenOptions, MethodSignature } from '../types'
import * as path from 'path'

/**
 * Generate TypeScript composable file from native blocks
 */
export function generateTypeScriptFile(
  blocks: NativeBlock[],
  componentName: string,
  options: CodegenOptions = {},
): GeneratedFile {
  const { includeHeader = true } = options

  // Filter blocks for this component
  const componentBlocks = blocks.filter(b => b.componentName === componentName)

  if (componentBlocks.length === 0) {
    throw new Error(`No native blocks found for component: ${componentName}`)
  }

  // Extract module name from first block
  const moduleName = extractModuleName(componentBlocks[0].content)

  // Extract method signatures from Swift/Kotlin code
  const methods = extractMethodSignatures(componentBlocks)

  // Generate the output path
  const outputDir = options.typescriptOutputDir || 'packages/runtime/src/generated'
  const outputPath = path.join(outputDir, `use${componentName}.ts`)

  // Generate the TypeScript code
  const content = generateTypeScriptContent(componentName, moduleName, methods, includeHeader)

  return {
    platform: 'ios', // TypeScript is platform-agnostic
    language: 'typescript',
    content,
    outputPath,
    sourceBlock: componentBlocks[0],
  }
}

/**
 * Generate the complete TypeScript file content
 */
function generateTypeScriptContent(
  componentName: string,
  moduleName: string,
  methods: MethodSignature[],
  includeHeader: boolean,
): string {
  const header = includeHeader ? generateTypeScriptHeader(componentName) : ''

  const composableName = `use${componentName}`
  const interfaceName = `${componentName}Module`

  // Generate method signatures for the interface
  const interfaceMethods = methods.map((method) => {
    const params = method.params
      .map((p: any) => `${p.name}${p.optional ? '?' : ''}: ${swiftToTsType(p.type)}`)
      .join(', ')
    const returnType = method.isAsync
      ? `Promise<${swiftToTsType(method.returnType)}>`
      : swiftToTsType(method.returnType)
    return `  ${method.name}(${params}): ${returnType}`
  }).join('\n\n')

  // Generate method implementations
  const implMethods = methods.map((method) => {
    const params = method.params
      .map((p: any) => `${p.name}${p.optional ? '?' : ''}: ${swiftToTsType(p.type)}`)
      .join(', ')
    const args = method.params.map((p: any) => p.name).join(', ')

    return `    ${method.name}(${params}) {
      return NativeBridge.invokeNativeModule('${moduleName}', '${method.name}', [${args}])
    }`
  }).join(',\n')

  return `${header}
import { NativeBridge } from '../bridge'

/**
 * Type-safe interface for the ${moduleName} native module
 * Auto-generated from <native> blocks in ${componentName}.vue
 */
export interface ${interfaceName} {
${interfaceMethods}
}

/**
 * Composable for using the ${moduleName} native module
 * 
 * @example
 * \`\`\`ts
 * import { ${composableName} } from '@thelacanians/vue-native-runtime'
 * 
 * const { ${methods[0]?.name || 'example'} } = ${composableName}()
 * \`\`\`
 */
export function ${composableName}(): ${interfaceName} {
  return {
${implMethods}
  }
}
`
}

/**
 * Generate TypeScript file header
 */
function generateTypeScriptHeader(componentName: string): string {
  return `// ────────────────────────────────────────────────────────────────────────────────
//  Auto-Generated Code
// ────────────────────────────────────────────────────────────────────────────────
//
//  Component: ${componentName}
//  Language: TypeScript
//
//  ⚠️  WARNING: This file is auto-generated. DO NOT EDIT MANUALLY.
//      Changes will be overwritten by the code generator.
//
//  Generated: ${new Date().toISOString()}
//
// ────────────────────────────────────────────────────────────────────────────────
`
}

/**
 * Extract method signatures from Swift and Kotlin code
 */
function extractMethodSignatures(blocks: NativeBlock[]): MethodSignature[] {
  const methods = new Map<string, MethodSignature>()

  for (const block of blocks) {
    if (block.language === 'swift') {
      const swiftMethods = extractSwiftMethods(block.content)
      for (const method of swiftMethods) {
        methods.set(method.name, method)
      }
    } else if (block.language === 'kotlin') {
      const kotlinMethods = extractKotlinMethods(block.content)
      for (const method of kotlinMethods) {
        // Prefer Swift signatures if available, otherwise use Kotlin
        if (!methods.has(method.name)) {
          methods.set(method.name, method)
        }
      }
    }
  }

  return Array.from(methods.values())
}

/**
 * Extract method signatures from Swift code
 */
function extractSwiftMethods(content: string): MethodSignature[] {
  const methods: MethodSignature[] = []

  // Match Swift method declarations in NativeModule implementation
  // func methodName(param1: Type1, param2: Type2) -> ReturnType
  const funcRegex = /func\s+(\w+)\s*\(([^)]*)\)\s*(?:->\s*(\w+(?:\s*\?)?))?/g

  let match: RegExpExecArray | null
  while ((match = funcRegex.exec(content)) !== null) {
    const [, name, paramsStr, returnType] = match

    // Skip the required NativeModule methods
    if (name === 'invoke' || name === 'invokeSync') {
      continue
    }

    const params = parseSwiftParams(paramsStr)
    const isAsync = params.some(p => p.name.includes('callback')) || returnType?.includes('Promise')

    methods.push({
      name,
      params: params.filter(p => !p.name.includes('callback')),
      returnType: returnType || 'void',
      isAsync,
    })
  }

  return methods
}

/**
 * Extract method signatures from Kotlin code
 */
function extractKotlinMethods(content: string): MethodSignature[] {
  const methods: MethodSignature[] = []

  // Match Kotlin method declarations
  // fun methodName(param1: Type1, param2: Type2): ReturnType
  const funcRegex = /(?:override\s+)?fun\s+(\w+)\s*\(([^)]*)\)\s*(?::\s*(\w+(?:\s*\?)?))?/g

  let match: RegExpExecArray | null
  while ((match = funcRegex.exec(content)) !== null) {
    const [, name, paramsStr, returnType] = match

    // Skip the required NativeModule methods
    if (name === 'invoke' || name === 'invokeSync') {
      continue
    }

    const params = parseKotlinParams(paramsStr)
    const isAsync = params.some(p => p.name.includes('callback'))

    methods.push({
      name,
      params: params.filter(p => !p.name.includes('callback')),
      returnType: returnType || 'Unit',
      isAsync,
    })
  }

  return methods
}

/**
 * Parse Swift function parameters
 */
function parseSwiftParams(paramsStr: string): Array<{ name: string, type: string, optional: boolean }> {
  if (!paramsStr.trim()) return []

  return paramsStr
    .split(',')
    .map((param) => {
      const trimmed = param.trim()
      const match = trimmed.match(/(\w+)\s*:\s*(\w+)(\?)?/)
      if (match) {
        return {
          name: match[1],
          type: match[2],
          optional: match[3] === '?',
        }
      }
      return { name: trimmed, type: 'Any', optional: false }
    })
}

/**
 * Parse Kotlin function parameters
 */
function parseKotlinParams(paramsStr: string): Array<{ name: string, type: string, optional: boolean }> {
  if (!paramsStr.trim()) return []

  return paramsStr
    .split(',')
    .map((param) => {
      const trimmed = param.trim()
      const match = trimmed.match(/(\w+)\s*:\s*(\w+)(\?)?/)
      if (match) {
        return {
          name: match[1],
          type: match[2],
          optional: match[3] === '?',
        }
      }
      return { name: trimmed, type: 'Any', optional: false }
    })
}

/**
 * Convert Swift/Kotlin types to TypeScript types
 */
function swiftToTsType(type: string): string {
  const typeMap: Record<string, string> = {
    'String': 'string',
    'String?': 'string | null',
    'Int': 'number',
    'Int?': 'number | null',
    'Double': 'number',
    'Double?': 'number | null',
    'Float': 'number',
    'Float?': 'number | null',
    'Bool': 'boolean',
    'Bool?': 'boolean | null',
    'Any': 'any',
    'Any?': 'any',
    'Void': 'void',
    'Unit': 'void',
  }

  return typeMap[type] || typeMap[type.replace(/\s*/g, '')] || 'any'
}

/**
 * Extract module name from Swift or Kotlin code
 */
function extractModuleName(content: string): string {
  // Try Swift pattern
  const swiftMatch = content.match(/var\s+moduleName\s*:\s*String\s*\{\s*"([^"]+)"\s*\}/)
  if (swiftMatch) {
    return swiftMatch[1]
  }

  // Try Kotlin pattern
  const kotlinMatch = content.match(/override\s+val\s+moduleName\s*:\s*String\s*=\s*"([^"]+)"/)
  if (kotlinMatch) {
    return kotlinMatch[1]
  }

  return 'Unknown'
}
