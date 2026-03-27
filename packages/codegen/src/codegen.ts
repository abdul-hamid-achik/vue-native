import * as fs from 'fs'
import * as path from 'path'
import type { NativeBlock, ParseError } from '@thelacanians/vue-native-sfc-parser'
import { generateSwiftFile, generateSwiftRegistration } from './generators/swift'
import { generateKotlinFile, generateKotlinRegistration } from './generators/kotlin'
import { generateTypeScriptFile } from './generators/typescript'
import { validateNativeBlocks } from './validator'
import type { CodegenOptions, CodegenResult, GeneratedFile } from './types'

function logInfo(message: string): void {
  process.stdout.write(`${message}\n`)
}

/**
 * Generate code from native blocks
 *
 * @param blocks - Array of native blocks to generate code for
 * @param options - Code generation options
 * @returns Code generation result
 */
export function generateCode(
  blocks: NativeBlock[],
  options: CodegenOptions = {},
): CodegenResult {
  const files: GeneratedFile[] = []
  const errors: ParseError[] = []
  const warnings: ParseError[] = []

  const {
    generateTypeScript = true,
    generateSwift = true,
    generateKotlin = true,
  } = options

  // Validate native blocks before generation
  const validation = validateNativeBlocks(blocks)
  errors.push(...validation.errors)
  warnings.push(...validation.warnings)

  // Stop if there are critical errors
  if (!validation.isValid) {
    return {
      files: [],
      errors,
      warnings,
      stats: {
        totalBlocks: blocks.length,
        swiftFiles: 0,
        kotlinFiles: 0,
        typescriptFiles: 0,
      },
    }
  }

  // Group blocks by component
  const blocksByComponent = groupBlocksByComponent(blocks)

  // Generate Swift files (iOS + macOS)
  if (generateSwift) {
    const iosBlocks = blocks.filter(b => b.platform === 'ios' || b.platform === 'macos')
    for (const block of iosBlocks) {
      try {
        const file = generateSwiftFile(block, options)
        files.push(file)
      } catch (error) {
        errors.push({
          file: block.sourceFile,
          message: `Failed to generate Swift code: ${(error as Error).message}`,
        })
      }
    }
  }

  // Generate Kotlin files (Android)
  if (generateKotlin) {
    const androidBlocks = blocks.filter(b => b.platform === 'android')
    for (const block of androidBlocks) {
      try {
        const file = generateKotlinFile(block, options)
        files.push(file)
      } catch (error) {
        errors.push({
          file: block.sourceFile,
          message: `Failed to generate Kotlin code: ${(error as Error).message}`,
        })
      }
    }
  }

  // Generate TypeScript files (composables)
  if (generateTypeScript) {
    for (const [componentName, componentBlocks] of blocksByComponent.entries()) {
      try {
        const file = generateTypeScriptFile(componentBlocks, componentName, options)
        files.push(file)
      } catch (error) {
        errors.push({
          file: componentBlocks[0]?.sourceFile || 'unknown',
          message: `Failed to generate TypeScript code: ${(error as Error).message}`,
        })
      }
    }
  }

  // Generate registration files
  if (generateSwift) {
    const iosBlocks = blocks.filter(b => b.platform === 'ios' || b.platform === 'macos')
    const swiftRegistration = generateSwiftRegistration(iosBlocks)
    const swiftRegPath = path.join(
      options.iosOutputDir || 'native/ios/VueNativeCore/Sources/VueNativeCore/Modules',
      'GeneratedModuleRegistry.swift',
    )
    files.push({
      platform: 'ios',
      language: 'swift',
      content: swiftRegistration,
      outputPath: swiftRegPath,
      sourceBlock: iosBlocks[0] || {
        platform: 'ios',
        language: 'swift',
        content: '',
        sourceFile: '',
        componentName: 'Generated',
        attributes: {},
      },
    })
  }

  if (generateKotlin) {
    const androidBlocks = blocks.filter(b => b.platform === 'android')
    const kotlinRegistration = generateKotlinRegistration(androidBlocks)
    const kotlinRegPath = path.join(
      options.androidOutputDir || 'native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/Modules',
      'GeneratedModuleRegistry.kt',
    )
    files.push({
      platform: 'android',
      language: 'kotlin',
      content: kotlinRegistration,
      outputPath: kotlinRegPath,
      sourceBlock: androidBlocks[0] || {
        platform: 'android',
        language: 'kotlin',
        content: '',
        sourceFile: '',
        componentName: 'Generated',
        attributes: {},
      },
    })
  }

  return {
    files,
    errors,
    warnings,
    stats: {
      totalBlocks: blocks.length,
      swiftFiles: files.filter(f => f.language === 'swift').length,
      kotlinFiles: files.filter(f => f.language === 'kotlin').length,
      typescriptFiles: files.filter(f => f.language === 'typescript').length,
    },
  }
}

/**
 * Write generated files to disk
 *
 * @param result - Code generation result
 * @param rootDir - Root directory of the project
 */
export function writeGeneratedFiles(
  result: CodegenResult,
  rootDir: string = process.cwd(),
): { written: number, errors: ParseError[] } {
  const written: number[] = []
  const errors: ParseError[] = []

  for (const file of result.files) {
    try {
      const absolutePath = path.resolve(rootDir, file.outputPath)
      const dir = path.dirname(absolutePath)

      // Ensure directory exists
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true })
      }

      // Write the file
      fs.writeFileSync(absolutePath, file.content, 'utf-8')
      written.push(1)

      logInfo(`[vue-native-codegen] Generated: ${file.outputPath}`)
    } catch (error) {
      errors.push({
        file: file.sourceBlock.sourceFile,
        message: `Failed to write ${file.outputPath}: ${(error as Error).message}`,
      })
    }
  }

  return {
    written: written.length,
    errors,
  }
}

/**
 * Clean generated files
 *
 * @param options - Codegen options
 * @param rootDir - Root directory of the project
 */
export function cleanGeneratedFiles(
  options: CodegenOptions,
  rootDir: string = process.cwd(),
): void {
  const dirs = [
    options.iosOutputDir || 'native/ios/VueNativeCore/Sources/VueNativeCore/GeneratedModules',
    options.androidOutputDir || 'native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/GeneratedModules',
    options.macosOutputDir || 'native/macos/VueNativeMacOS/Sources/VueNativeMacOS/GeneratedModules',
    options.typescriptOutputDir || 'packages/runtime/src/generated',
  ]

  for (const dir of dirs) {
    const absoluteDir = path.resolve(rootDir, dir)
    if (fs.existsSync(absoluteDir)) {
      const files = fs.readdirSync(absoluteDir)
      for (const file of files) {
        if (file.endsWith('.swift') || file.endsWith('.kt') || file.endsWith('.ts')) {
          const filePath = path.join(absoluteDir, file)
          fs.unlinkSync(filePath)
        }
      }
    }
  }
}

/**
 * Group blocks by component name
 */
function groupBlocksByComponent(blocks: NativeBlock[]): Map<string, NativeBlock[]> {
  const grouped = new Map<string, NativeBlock[]>()

  for (const block of blocks) {
    const existing = grouped.get(block.componentName) || []
    existing.push(block)
    grouped.set(block.componentName, existing)
  }

  return grouped
}
