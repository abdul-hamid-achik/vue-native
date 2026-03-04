import type { SFCBlock, SFCDescriptor } from '@vue/compiler-sfc'
import type { NativeBlock, ExtractOptions, ParseError } from './types'

/**
 * Valid platform values for <native> blocks
 */
const VALID_PLATFORMS = new Set(['ios', 'android', 'macos'])

/**
 * Valid language values for <native> blocks
 */
const VALID_LANGUAGES = new Set(['swift', 'kotlin'])

/**
 * Extract <native> blocks from a Vue SFC descriptor
 *
 * @param descriptor - SFC descriptor from @vue/compiler-sfc
 * @param options - Extraction options
 * @returns Array of native blocks and any errors
 */
export function extractNativeBlocks(
  descriptor: SFCDescriptor,
  options: ExtractOptions,
): { blocks: NativeBlock[], errors: ParseError[] } {
  const { sourceFile, includeSourceLocation = true } = options
  const componentName = options.componentName ?? getComponentNameFromPath(sourceFile)
  const errors: ParseError[] = []
  const blocks: NativeBlock[] = []

  // Find all <native> custom blocks
  const nativeBlocks = descriptor.customBlocks.filter(block => block.type === 'native')

  for (const block of nativeBlocks) {
    const result = processNativeBlock(block, {
      sourceFile,
      componentName,
      includeSourceLocation,
    })

    if (result.success) {
      blocks.push(result.block)
    } else {
      errors.push(result.error)
    }
  }

  return { blocks, errors }
}

/**
 * Process a single <native> block and validate it
 */
function processNativeBlock(
  block: SFCBlock,
  options: { sourceFile: string, componentName: string, includeSourceLocation: boolean },
): { success: true, block: NativeBlock } | { success: false, error: ParseError } {
  const { sourceFile, componentName, includeSourceLocation } = options
  const { attrs, content, loc } = block

  // Extract platform attribute
  const platform = extractPlatformAttr(attrs)
  if (!platform) {
    return {
      success: false,
      error: {
        file: sourceFile,
        message: '<native> block must specify a valid platform: "ios", "android", or "macos"',
        line: loc?.start.line,
        column: loc?.start.column,
      },
    }
  }

  // Determine language from platform or explicit attr
  const language = extractLanguageAttr(attrs, platform)
  if (!language) {
    return {
      success: false,
      error: {
        file: sourceFile,
        message: `Invalid language for platform "${platform}". Use "swift" for iOS/macOS or "kotlin" for Android.`,
        line: loc?.start.line,
        column: loc?.start.column,
      },
    }
  }

  // Validate content is not empty
  const trimmedContent = content.trim()
  if (!trimmedContent) {
    return {
      success: false,
      error: {
        file: sourceFile,
        message: '<native> block content cannot be empty',
        line: loc?.start.line,
        column: loc?.start.column,
      },
    }
  }

  // Build the native block object
  const nativeBlock: NativeBlock = {
    platform: platform as 'ios' | 'android' | 'macos',
    language: language as 'swift' | 'kotlin',
    content: trimmedContent,
    sourceFile,
    componentName,
    attributes: attrs as Record<string, string>,
  }

  // Add source location if requested
  if (includeSourceLocation && loc) {
    nativeBlock.startLine = loc.start.line
    nativeBlock.endLine = loc.end.line
  }

  return { success: true, block: nativeBlock }
}

/**
 * Extract platform from block attributes
 */
function extractPlatformAttr(attrs: SFCBlock['attrs']): string | null {
  // Check for platform="ios" | "android" | "macos"
  if (typeof attrs.platform === 'string') {
    const platform = attrs.platform.toLowerCase()
    if (VALID_PLATFORMS.has(platform)) {
      return platform
    }
  }

  // Check for platform-specific attributes: ios, android, macos
  // Handle both empty string (shorthand) and boolean true
  if ('ios' in attrs) {
    const val = attrs.ios
    if (val === '' || val === true || val === 'true') return 'ios'
  }
  if ('android' in attrs) {
    const val = attrs.android
    if (val === '' || val === true || val === 'true') return 'android'
  }
  if ('macos' in attrs) {
    const val = attrs.macos
    if (val === '' || val === true || val === 'true') return 'macos'
  }

  return null
}

/**
 * Extract language from block attributes
 * Defaults to swift for iOS/macOS, kotlin for Android
 */
function extractLanguageAttr(attrs: SFCBlock['attrs'], platform: string): string | null {
  // Explicit language attribute
  if (typeof attrs.lang === 'string') {
    const lang = attrs.lang.toLowerCase()
    if (VALID_LANGUAGES.has(lang)) {
      // Validate language matches platform
      if (platform === 'android' && lang !== 'kotlin') {
        return null
      }
      if ((platform === 'ios' || platform === 'macos') && lang !== 'swift') {
        return null
      }
      return lang
    }
  }

  // Check for swift/kotlin attributes
  if ('swift' in attrs) {
    const val = attrs.swift
    if (val === '' || val === true || val === 'true') {
      return platform === 'android' ? null : 'swift'
    }
  }
  if ('kotlin' in attrs) {
    const val = attrs.kotlin
    if (val === '' || val === true || val === 'true') {
      return platform === 'android' ? 'kotlin' : null
    }
  }

  // Default based on platform
  if (platform === 'android') return 'kotlin'
  if (platform === 'ios' || platform === 'macos') return 'swift'

  return null
}

/**
 * Extract component name from file path
 */
function getComponentNameFromPath(filePath: string): string {
  // Get filename without extension
  const filename = filePath.split('/').pop() || filePath.split('\\').pop() || 'Unknown'
  return filename.replace(/\.(vue|ts|js)$/, '')
}

/**
 * Get line number for a given position in source code
 */
export function getLineNumber(source: string, position: number): number {
  return source.substring(0, position).split('\n').length
}
