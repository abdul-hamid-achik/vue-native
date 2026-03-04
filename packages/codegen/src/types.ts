import type { NativeBlock, NativePlatform, ParseError } from '@thelacanians/vue-native-sfc-parser'

/**
 * Code generation options
 */
export interface CodegenOptions {
  /**
   * Root directory of the project (for resolving output paths)
   */
  root?: string

  /**
   * Output directory for generated Swift code (iOS)
   * @default 'native/ios/VueNativeCore/Sources/VueNativeCore/GeneratedModules'
   */
  iosOutputDir?: string

  /**
   * Output directory for generated Kotlin code (Android)
   * @default 'native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/GeneratedModules'
   */
  androidOutputDir?: string

  /**
   * Output directory for generated Swift code (macOS)
   * @default 'native/macos/VueNativeMacOS/Sources/VueNativeMacOS/GeneratedModules'
   */
  macosOutputDir?: string

  /**
   * Output directory for generated TypeScript files
   * @default 'packages/runtime/src/generated'
   */
  typescriptOutputDir?: string

  /**
   * Whether to generate TypeScript composables
   * @default true
   */
  generateTypeScript?: boolean

  /**
   * Whether to generate Swift code
   * @default true
   */
  generateSwift?: boolean

  /**
   * Whether to generate Kotlin code
   * @default true
   */
  generateKotlin?: boolean

  /**
   * Whether to include auto-generation header in output files
   * @default true
   */
  includeHeader?: boolean
}

/**
 * Generated file information
 */
export interface GeneratedFile {
  /** Platform this file is for */
  platform: NativePlatform

  /** Language of the generated code */
  language: 'swift' | 'kotlin' | 'typescript'

  /** Generated source code */
  content: string

  /** Output file path (absolute) */
  outputPath: string

  /** Source block this was generated from */
  sourceBlock: NativeBlock
}

/**
 * Code generation result
 */
export interface CodegenResult {
  /** All generated files */
  files: GeneratedFile[]

  /** Generation errors */
  errors: ParseError[]

  /** Warnings (non-fatal issues) */
  warnings: ParseError[]

  /** Statistics */
  stats: {
    totalBlocks: number
    swiftFiles: number
    kotlinFiles: number
    typescriptFiles: number
  }
}

/**
 * Method signature extracted from native code
 */
export interface MethodSignature {
  /** Method name */
  name: string

  /** Parameters */
  params: Array<{
    name: string
    type: string
    optional: boolean
  }>

  /** Return type */
  returnType: string

  /** Whether the method is async (returns a Promise/callback) */
  isAsync: boolean
}

/**
 * Validation result with errors and warnings
 */
export interface ValidationResult {
  errors: ParseError[]
  warnings: ParseError[]
  isValid: boolean
}

/**
 * Parsed module information
 */
export interface ParsedModule {
  /** Module class name */
  className: string

  /** Module name (from moduleName property) */
  moduleName: string

  /** Extracted method signatures */
  methods: MethodSignature[]

  /** Raw source code */
  source: string
}
