/**
 * @thelacanians/vue-native-codegen
 *
 * Code generator for Vue Native <native> blocks.
 * Generates Swift, Kotlin, and TypeScript code from native blocks extracted from Vue SFCs.
 *
 * @example
 * ```ts
 * import { parseDirectory } from '@thelacanians/vue-native-sfc-parser'
 * import { generateCode, writeGeneratedFiles, validateNativeBlocks } from '@thelacanians/vue-native-codegen'
 *
 * // Parse SFCs to extract native blocks
 * const result = parseDirectory('app/', { exclude: ['node_modules', 'dist'] })
 *
 * // Validate native blocks
 * const validation = validateNativeBlocks(result.allNativeBlocks)
 * if (!validation.isValid) {
 *   console.error('Validation errors:', validation.errors)
 * }
 *
 * // Generate code
 * const codegen = generateCode(result.allNativeBlocks)
 *
 * // Write to disk
 * writeGeneratedFiles(codegen)
 *
 * console.log(`Generated ${codegen.stats.swiftFiles} Swift files`)
 * console.log(`Generated ${codegen.stats.kotlinFiles} Kotlin files`)
 * console.log(`Generated ${codegen.stats.typescriptFiles} TypeScript files`)
 * ```
 *
 * @packageDocumentation
 */

export { generateCode, writeGeneratedFiles, cleanGeneratedFiles } from './codegen'

export {
  validateNativeBlocks,
  formatValidationErrors,
  getDiagnostics,
} from './validator'

export {
  generateSwiftFile,
  generateSwiftRegistration,
} from './generators/swift'

export {
  generateKotlinFile,
  generateKotlinRegistration,
} from './generators/kotlin'

export {
  generateTypeScriptFile,
} from './generators/typescript'

export type {
  CodegenOptions,
  CodegenResult,
  GeneratedFile,
  MethodSignature,
  ParsedModule,
  ValidationResult,
} from './types'
