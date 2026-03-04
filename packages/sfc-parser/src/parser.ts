import { parse } from '@vue/compiler-sfc'
import { readFileSync, readdirSync } from 'node:fs'
import { resolve, join } from 'node:path'
import { extractNativeBlocks } from './extractor'
import type {
  ParsedSFC,
  ParseResult,
  ParserOptions,
  NativeBlock,
  ParseError,
} from './types'

/**
 * Parse a single Vue SFC file and extract <native> blocks
 *
 * @param source - The SFC source code
 * @param options - Parser options
 * @returns Parsed SFC with native blocks
 */
export function parseSFC(
  source: string,
  options: { sourceFile: string, parserOptions?: ParserOptions },
): ParsedSFC {
  const { sourceFile, parserOptions = {} } = options
  const errors: ParseError[] = []

  // Parse the SFC using @vue/compiler-sfc
  const { descriptor, errors: parseErrors } = parse(source, {
    filename: sourceFile,
  })

  // Convert parse errors to our format
  for (const error of parseErrors) {
    errors.push({
      file: sourceFile,
      message: error.message,
      line: (error as any).loc?.start.line,
      column: (error as any).loc?.start.column,
    })
  }

  // Extract native blocks
  const { blocks: nativeBlocks, errors: extractErrors } = extractNativeBlocks(descriptor, {
    sourceFile,
    includeSourceLocation: parserOptions.includeSourceLocation ?? true,
  })

  // Merge errors
  errors.push(...extractErrors)

  return {
    descriptor,
    nativeBlocks,
    sourceFile,
    errors,
  }
}

/**
 * Parse a Vue SFC file from disk
 *
 * @param filePath - Absolute path to the .vue file
 * @param options - Parser options
 * @returns Parsed SFC with native blocks
 */
export function parseSFCFile(
  filePath: string,
  options: ParserOptions = {},
): ParsedSFC {
  const absolutePath = resolve(options.root || globalThis.process.cwd(), filePath)

  // Read the file
  let source: string
  try {
    source = readFileSync(absolutePath, 'utf-8')
  } catch (error) {
    return {
      descriptor: null as any,
      nativeBlocks: [],
      sourceFile: absolutePath,
      errors: [{
        file: absolutePath,
        message: `Failed to read file: ${(error as Error).message}`,
      }],
    }
  }

  return parseSFC(source, {
    sourceFile: absolutePath,
    parserOptions: options,
  })
}

/**
 * Parse multiple Vue SFC files
 *
 * @param filePaths - Array of absolute paths to .vue files
 * @param options - Parser options
 * @returns Aggregated parse result
 */
export function parseSFCFiles(
  filePaths: string[],
  options: ParserOptions = {},
): ParseResult {
  const sfcs: ParsedSFC[] = []
  const allNativeBlocks: NativeBlock[] = []
  const errors: ParseError[] = []

  for (const filePath of filePaths) {
    const result = parseSFCFile(filePath, options)
    sfcs.push(result)
    allNativeBlocks.push(...result.nativeBlocks)
    errors.push(...result.errors)
  }

  return {
    sfcs,
    allNativeBlocks,
    errors,
  }
}

/**
 * Parse a directory recursively for Vue SFC files
 *
 * @param dirPath - Directory to scan
 * @param options - Parser options
 * @returns Aggregated parse result
 */
export function parseDirectory(
  dirPath: string,
  options: ParserOptions & { exclude?: string[] } = {},
): ParseResult {
  const { exclude = ['node_modules', 'dist', '.git', '.turbo'], ...parserOptions } = options
  const absoluteDir = resolve(options.root || globalThis.process.cwd(), dirPath)

  const vueFiles: string[] = []

  // Recursively find all .vue files
  function scanDirectory(dir: string): void {
    const entries = readdirSync(dir, { withFileTypes: true })

    for (const entry of entries) {
      const fullPath = join(dir, entry.name)

      // Skip excluded directories
      if (entry.isDirectory() && exclude.includes(entry.name)) {
        continue
      }

      if (entry.isFile() && entry.name.endsWith('.vue')) {
        vueFiles.push(fullPath)
      } else if (entry.isDirectory()) {
        scanDirectory(fullPath)
      }
    }
  }

  scanDirectory(absoluteDir)

  return parseSFCFiles(vueFiles, parserOptions)
}

/**
 * Get all native blocks from a parse result, optionally filtered by platform
 *
 * @param result - Parse result from parseSFCFiles or parseDirectory
 * @param platform - Optional platform filter
 * @returns Filtered array of native blocks
 */
export function getNativeBlocks(
  result: ParseResult,
  platform?: 'ios' | 'android' | 'macos',
): NativeBlock[] {
  if (!platform) {
    return result.allNativeBlocks
  }

  return result.allNativeBlocks.filter(block => block.platform === platform)
}

/**
 * Get native blocks for a specific component
 *
 * @param result - Parse result
 * @param componentName - Component name to filter by
 * @returns Native blocks for the component
 */
export function getComponentNativeBlocks(
  result: ParseResult,
  componentName: string,
): NativeBlock[] {
  return result.allNativeBlocks.filter(block => block.componentName === componentName)
}

/**
 * Group native blocks by component
 *
 * @param blocks - Array of native blocks
 * @returns Map of component name to native blocks
 */
export function groupBlocksByComponent(
  blocks: NativeBlock[],
): Map<string, NativeBlock[]> {
  const grouped = new Map<string, NativeBlock[]>()

  for (const block of blocks) {
    const existing = grouped.get(block.componentName) || []
    existing.push(block)
    grouped.set(block.componentName, existing)
  }

  return grouped
}

/**
 * Group native blocks by platform
 *
 * @param blocks - Array of native blocks
 * @returns Map of platform to native blocks
 */
export function groupBlocksByPlatform(
  blocks: NativeBlock[],
): Map<'ios' | 'android' | 'macos', NativeBlock[]> {
  const grouped = new Map<'ios' | 'android' | 'macos', NativeBlock[]>()
  grouped.set('ios', [])
  grouped.set('android', [])
  grouped.set('macos', [])

  for (const block of blocks) {
    const existing = grouped.get(block.platform) || []
    existing.push(block)
    grouped.set(block.platform, existing)
  }

  return grouped
}
