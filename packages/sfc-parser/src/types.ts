import type { SFCDescriptor } from '@vue/compiler-sfc'

/**
 * Platform target for native code generation
 */
export type NativePlatform = 'ios' | 'android' | 'macos'

/**
 * Programming language for native code
 */
export type NativeLanguage = 'swift' | 'kotlin'

/**
 * Represents a <native> block extracted from a Vue SFC
 */
export interface NativeBlock {
  /** Platform target (ios, android, macos) */
  platform: NativePlatform

  /** Language (swift, kotlin) */
  language: NativeLanguage

  /** The raw source code content of the block */
  content: string

  /** Absolute path to the source SFC file */
  sourceFile: string

  /** Component name derived from the SFC filename */
  componentName: string

  /** Line number where the <native> block starts in the SFC */
  startLine?: number

  /** Line number where the <native> block ends in the SFC */
  endLine?: number

  /** Attributes from the <native> tag */
  attributes: Record<string, string>
}

/**
 * Result of parsing a single SFC file
 */
export interface ParsedSFC {
  /** Vue SFC descriptor from @vue/compiler-sfc */
  descriptor: SFCDescriptor

  /** All <native> blocks found in the SFC */
  nativeBlocks: NativeBlock[]

  /** Path to the source file */
  sourceFile: string

  /** Parse errors, if any */
  errors: ParseError[]
}

/**
 * Result of parsing multiple SFC files
 */
export interface ParseResult {
  /** All parsed SFCs */
  sfcs: ParsedSFC[]

  /** All native blocks aggregated from all SFCs */
  allNativeBlocks: NativeBlock[]

  /** Files that failed to parse */
  errors: ParseError[]
}

/**
 * Parse error information
 */
export interface ParseError {
  /** File path where the error occurred */
  file: string

  /** Error message */
  message: string

  /** Line number, if available */
  line?: number

  /** Column number, if available */
  column?: number
}

/**
 * Options for the SFC parser
 */
export interface ParserOptions {
  /**
   * Root directory of the project (for resolving relative paths)
   */
  root?: string

  /**
   * Whether to extract detailed source location information
   * @default true
   */
  includeSourceLocation?: boolean

  /**
   * Custom function to validate native block syntax
   */
  validate?: (block: NativeBlock) => ParseError | null
}

/**
 * Options for extracting native blocks from a single SFC
 */
export interface ExtractOptions {
  /** Source file path (for error reporting) */
  sourceFile: string

  /** Component name (defaults to filename without extension) */
  componentName?: string

  /** Whether to include source location info */
  includeSourceLocation?: boolean
}

/**
 * Generated code output from a native block
 */
export interface GeneratedCode {
  /** Platform this code is for */
  platform: NativePlatform

  /** Language of the generated code */
  language: 'swift' | 'kotlin' | 'typescript'

  /** Generated source code */
  code: string

  /** Output file path (relative to project root) */
  outputPath: string

  /** Source SFC this was generated from */
  sourceFile: string

  /** Component name */
  componentName: string
}

/**
 * Code generation result
 */
export interface CodegenResult {
  /** All generated files */
  files: GeneratedCode[]

  /** Generation errors */
  errors: ParseError[]

  /** Warnings (non-fatal issues) */
  warnings: ParseError[]
}
