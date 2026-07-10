import type { NativeBlock } from '@thelacanians/vue-native-sfc-parser'
import type { GeneratedFile, CodegenOptions, MethodSignature } from '../types'
import * as path from 'path'

type MethodParameter = MethodSignature['params'][number]

/**
 * Generate TypeScript composable file from native blocks
 */
export function generateTypeScriptFile(
  blocks: NativeBlock[],
  componentName: string,
  options: CodegenOptions = {},
): GeneratedFile {
  const { includeHeader = true } = options

  // Callers pass the blocks that belong to one generated API. Do not filter by
  // SFC component name here: one SFC may legitimately declare several native
  // modules, each of which needs its own composable.
  if (blocks.length === 0) {
    throw new Error(`No native blocks found for component: ${componentName}`)
  }
  const componentBlocks = blocks

  // Extract module name from first block
  const moduleName = extractModuleName(componentBlocks[0].content)

  // Extract method signatures from Swift/Kotlin code
  const methods = extractMethodSignatures(componentBlocks)

  // Generate the output path
  const outputDir = options.typescriptOutputDir || 'packages/runtime/src/generated'
  const outputPath = path.join(outputDir, `use${componentName}.ts`)

  // Generate the TypeScript code
  const content = generateTypeScriptContent(
    componentName,
    componentBlocks[0].componentName,
    moduleName,
    methods,
    includeHeader,
  )

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
  sourceComponentName: string,
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
      .map((p: MethodParameter) => `${p.name}${p.optional ? '?' : ''}: ${swiftToTsType(p.type)}`)
      .join(', ')
    // Every generated implementation uses invokeNativeModule(), whose result
    // is delivered through the asynchronous native callback bridge. Exposing
    // a synchronous-looking signature here lets callers accidentally ignore
    // errors and disagrees with the value returned at runtime.
    const returnType = `Promise<${swiftToTsType(method.returnType)}>`
    return `  ${formatMethodName(method.name)}(${params}): ${returnType}`
  }).join('\n\n')

  // Generate method implementations
  const implMethods = methods.map((method) => {
    const params = method.params
      .map((p: MethodParameter) => `${p.name}${p.optional ? '?' : ''}: ${swiftToTsType(p.type)}`)
      .join(', ')
    const args = method.params.map((p: MethodParameter) => p.name).join(', ')

    return `    ${formatMethodName(method.name)}(${params}) {
      return NativeBridge.invokeNativeModule('${moduleName}', '${method.name}', [${args}])
    }`
  }).join(',\n')

  return `${header}
import { NativeBridge } from '@thelacanians/vue-native-runtime'

/**
 * Type-safe interface for the ${moduleName} native module
 * Auto-generated from <native> blocks in ${sourceComponentName}.vue
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
  const decoded = decodeEntities(content)
  const helpers = extractSwiftHelpers(decoded)
  const invokeBody = extractBracedBody(decoded, /\bfunc\s+invoke\s*\(/)
  return invokeBody ? extractDispatchedMethods(invokeBody, 'swift', helpers) : []
}

/**
 * Extract method signatures from Kotlin code
 */
function extractKotlinMethods(content: string): MethodSignature[] {
  const decoded = decodeEntities(content)
  const helpers = extractKotlinHelpers(decoded)
  const invokeBody = extractBracedBody(decoded, /\bfun\s+invoke\s*\(/)
  return invokeBody ? extractDispatchedMethods(invokeBody, 'kotlin', helpers) : []
}

function extractSwiftHelpers(content: string): MethodSignature[] {
  const methods: MethodSignature[] = []
  const funcRegex = /func\s+(\w+)\s*\(([^)]*)\)\s*(?:->\s*([^\n{]+))?/g
  let match: RegExpExecArray | null

  while ((match = funcRegex.exec(content)) !== null) {
    const [, name, paramsStr, returnType] = match
    if (name === 'invoke' || name === 'invokeSync') continue
    methods.push({
      name,
      params: parseSwiftParams(paramsStr),
      returnType: returnType?.trim() || 'void',
      isAsync: true,
    })
  }

  return methods
}

function extractKotlinHelpers(content: string): MethodSignature[] {
  const methods: MethodSignature[] = []
  const funcRegex = /(?:override\s+)?fun\s+(\w+)\s*\(([^)]*)\)\s*(?::\s*([^\n={]+))?/g
  let match: RegExpExecArray | null

  while ((match = funcRegex.exec(content)) !== null) {
    const [, name, paramsStr, returnType] = match
    if (name === 'invoke' || name === 'invokeSync') continue
    methods.push({
      name,
      params: parseKotlinParams(paramsStr),
      returnType: returnType?.trim() || 'Unit',
      isAsync: true,
    })
  }

  return methods
}

function extractDispatchedMethods(
  invokeBody: string,
  language: 'swift' | 'kotlin',
  helpers: MethodSignature[],
): MethodSignature[] {
  return extractDispatchCases(invokeBody, language).map((dispatchCase) => {
    const helper = helpers
      .map(method => ({ method, index: dispatchCase.body.search(new RegExp(`\\b${escapeRegExp(method.name)}\\s*\\(`)) }))
      .filter(candidate => candidate.index >= 0)
      .sort((left, right) => left.index - right.index)[0]?.method

    return {
      name: dispatchCase.name,
      params: helper?.params ?? inferBridgeParameters(dispatchCase.body, language),
      returnType: helper?.returnType ?? inferCallbackReturnType(dispatchCase.body),
      isAsync: true,
    }
  })
}

interface DispatchMarker {
  line: number
  depth: number
  name?: string
  tail: string
}

function extractDispatchCases(
  invokeBody: string,
  language: 'swift' | 'kotlin',
): Array<{ name: string, body: string }> {
  const lines = invokeBody.split('\n')
  const markers: DispatchMarker[] = []
  let depth = 0

  for (const [lineIndex, line] of lines.entries()) {
    const namedPattern = language === 'swift'
      ? /^\s*case\s+"([^"]+)"\s*:/
      : /^\s*"([^"]+)"\s*->/
    const fallbackPattern = language === 'swift'
      ? /^\s*default\s*:/
      : /^\s*else\s*->/
    const named = line.match(namedPattern)
    const fallback = line.match(fallbackPattern)

    if (named) {
      markers.push({ line: lineIndex, depth, name: named[1], tail: line.slice(named[0].length) })
    } else if (fallback) {
      markers.push({ line: lineIndex, depth, tail: line.slice(fallback[0].length) })
    }

    depth += braceDepthDelta(line)
  }

  const namedMarkers = markers.filter((marker): marker is DispatchMarker & { name: string } => marker.name !== undefined)
  if (namedMarkers.length === 0) return []
  const dispatchDepth = Math.min(...namedMarkers.map(marker => marker.depth))
  const dispatchMarkers = markers.filter(marker => marker.depth === dispatchDepth)

  return dispatchMarkers.flatMap((marker, index) => {
    if (!marker.name) return []
    const nextLine = dispatchMarkers[index + 1]?.line ?? lines.length
    const bodyLines = [marker.tail, ...lines.slice(marker.line + 1, nextLine)]
    return [{ name: marker.name, body: bodyLines.join('\n') }]
  })
}

function braceDepthDelta(line: string): number {
  const code = line
    .replace(/"(?:\\.|[^"\\])*"/g, '""')
    .replace(/\/\/.*$/, '')
  return (code.match(/{/g)?.length ?? 0) - (code.match(/}/g)?.length ?? 0)
}

function extractBracedBody(content: string, declarationPattern: RegExp): string | undefined {
  const declaration = declarationPattern.exec(content)
  if (!declaration) return undefined
  const openingBrace = content.indexOf('{', declaration.index + declaration[0].length)
  if (openingBrace === -1) return undefined

  let depth = 1
  let quote: '"' | '\'' | null = null
  let escaped = false
  for (let index = openingBrace + 1; index < content.length; index++) {
    const char = content[index]
    const next = content[index + 1]

    if (quote) {
      if (escaped) {
        escaped = false
      } else if (char === '\\') {
        escaped = true
      } else if (char === quote) {
        quote = null
      }
      continue
    }

    if (char === '"' || char === '\'') {
      quote = char
      continue
    }
    if (char === '/' && next === '/') {
      const newline = content.indexOf('\n', index + 2)
      if (newline === -1) return undefined
      index = newline
      continue
    }
    if (char === '{') depth++
    if (char === '}') {
      depth--
      if (depth === 0) return content.slice(openingBrace + 1, index)
    }
  }

  return undefined
}

function inferBridgeParameters(
  body: string,
  language: 'swift' | 'kotlin',
): MethodSignature['params'] {
  const parameters = new Map<number, MethodParameter>()
  for (const line of body.split('\n')) {
    const argMatches = [...line.matchAll(/args\[(\d+)\]/g)]
    for (const argMatch of argMatches) {
      const index = Number(argMatch[1])
      if (parameters.has(index)) continue
      const prefix = line.slice(0, argMatch.index)
      const suffix = line.slice((argMatch.index ?? 0) + argMatch[0].length)
      const variableName = prefix.match(/(?:let|var|val)\s+(\w+)[^=]*=\s*$/)?.[1] ?? `arg${index}`
      const castType = suffix.match(/^\s+as[!?]?\s+(.+?)(?=\s*(?:\?\?|\?:|$))/)?.[1]?.trim()
      parameters.set(index, {
        name: variableName,
        type: castType || (language === 'swift' ? 'Any' : 'Any?'),
        optional: false,
      })
    }
  }

  return [...parameters.entries()]
    .sort(([left], [right]) => left - right)
    .map(([, parameter]) => parameter)
}

function inferCallbackReturnType(body: string): string {
  const callbackValues = [...body.matchAll(/callback\s*\(\s*([^,\n]+)/g)]
    .map(match => match[1].trim())
    .filter(value => value !== 'nil' && value !== 'null')
  const value = callbackValues[0]
  if (!value) return 'void'
  if (/^"/.test(value)) return 'String'
  if (/^(?:true|false)$/.test(value)) return 'Bool'
  if (/^-?\d+(?:\.\d+)?$/.test(value)) return 'Double'
  return 'Any'
}

/**
 * Parse Swift function parameters
 */
function parseSwiftParams(paramsStr: string): Array<{ name: string, type: string, optional: boolean }> {
  if (!paramsStr.trim()) return []

  return splitParameters(paramsStr)
    .map((param) => {
      const trimmed = param.trim()
      const match = trimmed.match(/(?:(?:\w+|_)\s+)?(\w+)\s*:\s*(.+)$/)
      if (match) {
        const type = match[2].trim()
        return {
          name: match[1],
          type,
          optional: type.endsWith('?'),
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

  return splitParameters(paramsStr)
    .map((param) => {
      const trimmed = param.trim()
      const match = trimmed.match(/(\w+)\s*:\s*(.+)$/)
      if (match) {
        const type = match[2].trim()
        return {
          name: match[1],
          type,
          optional: type.endsWith('?'),
        }
      }
      return { name: trimmed, type: 'Any', optional: false }
    })
}

function splitParameters(params: string): string[] {
  const result: string[] = []
  let start = 0
  let depth = 0

  for (let index = 0; index < params.length; index++) {
    const char = params[index]
    if ('<([{'.includes(char)) depth++
    if ('>)]}'.includes(char)) depth--
    if (char === ',' && depth === 0) {
      result.push(params.slice(start, index))
      start = index + 1
    }
  }
  result.push(params.slice(start))
  return result
}

/**
 * Convert Swift/Kotlin types to TypeScript types
 */
function swiftToTsType(type: string): string {
  const normalized = type.replace(/\s+/g, '')
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
    'void': 'void',
    'Void': 'void',
    'Unit': 'void',
  }

  if (typeMap[type]) return typeMap[type]
  if (typeMap[normalized]) return typeMap[normalized]

  if (normalized.endsWith('?')) {
    return `${swiftToTsType(normalized.slice(0, -1))} | null`
  }

  const swiftArray = normalized.match(/^\[(.+)\]$/)
  if (swiftArray && !swiftArray[1].includes(':')) {
    return `${swiftToTsType(swiftArray[1])}[]`
  }
  const genericArray = normalized.match(/^(?:List|Array)<(.+)>$/)
  if (genericArray) {
    return `${swiftToTsType(genericArray[1])}[]`
  }
  const swiftDictionary = normalized.match(/^\[String:(.+)\]$/)
  const genericMap = normalized.match(/^(?:Map|Dictionary)<String,(.+)>$/)
  if (swiftDictionary || genericMap) {
    return `Record<string, ${swiftToTsType((swiftDictionary ?? genericMap)![1])}>`
  }

  return 'any'
}

function formatMethodName(name: string): string {
  return /^[A-Za-z_$][\w$]*$/.test(name) ? name : JSON.stringify(name)
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

function decodeEntities(content: string): string {
  return content
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&')
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
