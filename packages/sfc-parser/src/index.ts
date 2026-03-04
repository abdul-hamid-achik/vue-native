/**
 * @thelacanians/vue-native-sfc-parser
 *
 * Vue Native SFC parser for extracting <native> blocks from Vue Single File Components.
 *
 * @example
 * ```ts
 * import { parseSFCFile, parseDirectory, getNativeBlocks } from '@thelacanians/vue-native-sfc-parser'
 *
 * // Parse a single file
 * const result = parseSFCFile('app/components/MyComponent.vue')
 *
 * // Parse entire directory
 * const allResults = parseDirectory('app/', { exclude: ['node_modules', 'dist'] })
 *
 * // Get native blocks for iOS
 * const iosBlocks = getNativeBlocks(allResults, 'ios')
 *
 * // Group by component
 * const byComponent = groupBlocksByComponent(allResults.allNativeBlocks)
 * ```
 *
 * @packageDocumentation
 */

export {
  parseSFC,
  parseSFCFile,
  parseSFCFiles,
  parseDirectory,
  getNativeBlocks,
  getComponentNativeBlocks,
  groupBlocksByComponent,
  groupBlocksByPlatform,
} from './parser'

export { extractNativeBlocks } from './extractor'

export type {
  NativeBlock,
  NativePlatform,
  NativeLanguage,
  ParsedSFC,
  ParseResult,
  ParseError,
  ParserOptions,
  ExtractOptions,
  GeneratedCode,
  CodegenResult,
} from './types'
