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

function registrationSourceBlock(platform: 'ios' | 'android' | 'macos'): NativeBlock {
  return {
    platform,
    language: platform === 'android' ? 'kotlin' : 'swift',
    content: '',
    sourceFile: '<generated module registry>',
    componentName: 'GeneratedModuleRegistry',
    attributes: {},
  }
}

function generatedModuleDirectory(platform: 'ios' | 'android' | 'macos', options: CodegenOptions): string {
  switch (platform) {
    case 'ios':
      return options.iosOutputDir || 'native/ios/VueNativeCore/Sources/VueNativeCore/GeneratedModules'
    case 'android':
      return options.androidOutputDir || 'native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/GeneratedModules'
    case 'macos':
      return options.macosOutputDir || 'native/macos/VueNativeMacOS/Sources/VueNativeMacOS/GeneratedModules'
  }
}

function registrationOutputPath(platform: 'ios' | 'android' | 'macos', options: CodegenOptions): string {
  const customOutputDir = platform === 'ios'
    ? options.iosOutputDir
    : platform === 'android'
      ? options.androidOutputDir
      : options.macosOutputDir
  const defaultModuleDir = platform === 'ios'
    ? 'native/ios/VueNativeCore/Sources/VueNativeCore/Modules'
    : platform === 'android'
      ? 'native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/Modules'
      : 'native/macos/VueNativeMacOS/Sources/VueNativeMacOS/Modules'
  return path.join(customOutputDir || defaultModuleDir, `GeneratedModuleRegistry.${platform === 'android' ? 'kt' : 'swift'}`)
}

function isGeneratedArtifact(filePath: string): boolean {
  try {
    const content = fs.readFileSync(filePath, 'utf-8')
    return content.includes('Auto-Generated Code')
      || content.includes('Auto-generated module registration')
      || content.includes('Auto-Generated Module Registration')
  } catch {
    return false
  }
}

function removeGeneratedFile(filePath: string): void {
  if (fs.existsSync(filePath) && isGeneratedArtifact(filePath)) {
    fs.unlinkSync(filePath)
  }
}

function directoryContainsGeneratedArtifact(directory: string): boolean {
  try {
    return fs.readdirSync(directory).some((entry) => {
      const filePath = path.join(directory, entry)
      return fs.statSync(filePath).isFile() && isGeneratedArtifact(filePath)
    })
  } catch {
    return false
  }
}

/**
 * Whether a project has generator-owned output that needs to be maintained.
 *
 * This lets integrations distinguish a project where the final `<native>`
 * block was removed (clean stale output) from a JavaScript-only project that
 * has never opted into generated native sources (leave its tree untouched).
 */
export function hasGeneratedArtifacts(
  options: CodegenOptions = {},
  rootDir: string = process.cwd(),
): boolean {
  const generatedDirectories = [
    generatedModuleDirectory('ios', options),
    generatedModuleDirectory('android', options),
    generatedModuleDirectory('macos', options),
    options.typescriptOutputDir || 'packages/runtime/src/generated',
  ]

  if (generatedDirectories.some(directory => directoryContainsGeneratedArtifact(path.resolve(rootDir, directory)))) {
    return true
  }

  return (['ios', 'android', 'macos'] as const)
    .some(platform => isGeneratedArtifact(path.resolve(rootDir, registrationOutputPath(platform, options))))
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

  // A single SFC can declare multiple native modules. Generate one TypeScript
  // API per module name so methods are never routed to a sibling module merely
  // because both blocks came from the same Vue component.
  const blocksByModule = groupBlocksByModule(blocks)

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
    const generatedNames = new Map<string, string>()
    for (const [moduleName, moduleBlocks] of blocksByModule.entries()) {
      const generatedName = toTypeScriptIdentifier(moduleName)
      const previousModule = generatedNames.get(generatedName)
      if (previousModule && previousModule !== moduleName) {
        errors.push({
          file: moduleBlocks[0]?.sourceFile || 'unknown',
          message: `Native modules '${previousModule}' and '${moduleName}' map to the same generated TypeScript name '${generatedName}'`,
        })
        continue
      }
      generatedNames.set(generatedName, moduleName)

      try {
        const file = generateTypeScriptFile(moduleBlocks, generatedName, options)
        files.push(file)
      } catch (error) {
        errors.push({
          file: moduleBlocks[0]?.sourceFile || 'unknown',
          message: `Failed to generate TypeScript code: ${(error as Error).message}`,
        })
      }
    }
  }

  // Generate registration files
  if (generateSwift) {
    const iosBlocks = blocks.filter(b => b.platform === 'ios')
    const macosBlocks = blocks.filter(b => b.platform === 'macos')

    // Always overwrite both registries, including with an empty extension.
    // Otherwise deleting the final block leaves a stale registry that refers
    // to generated classes which no longer exist.
    files.push({
      platform: 'ios',
      language: 'swift',
      content: generateSwiftRegistration(iosBlocks, { platform: 'ios' }),
      outputPath: registrationOutputPath('ios', options),
      sourceBlock: iosBlocks[0] ?? registrationSourceBlock('ios'),
    })
    files.push({
      platform: 'macos',
      language: 'swift',
      content: generateSwiftRegistration(macosBlocks, { platform: 'macos' }),
      outputPath: registrationOutputPath('macos', options),
      sourceBlock: macosBlocks[0] ?? registrationSourceBlock('macos'),
    })
  }

  if (generateKotlin) {
    const androidBlocks = blocks.filter(b => b.platform === 'android')
    files.push({
      platform: 'android',
      language: 'kotlin',
      content: generateKotlinRegistration(androidBlocks),
      outputPath: registrationOutputPath('android', options),
      sourceBlock: androidBlocks[0] ?? registrationSourceBlock('android'),
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
  const dirs: Array<{ path: string, extensions: string[] }> = [
    { path: generatedModuleDirectory('ios', options), extensions: ['.swift'] },
    { path: generatedModuleDirectory('android', options), extensions: ['.kt'] },
    { path: generatedModuleDirectory('macos', options), extensions: ['.swift'] },
    { path: options.typescriptOutputDir || 'packages/runtime/src/generated', extensions: ['.ts'] },
  ]

  for (const dir of dirs) {
    const absoluteDir = path.resolve(rootDir, dir.path)
    if (fs.existsSync(absoluteDir)) {
      const files = fs.readdirSync(absoluteDir)
      for (const file of files) {
        if (dir.extensions.some(extension => file.endsWith(extension))) {
          const filePath = path.join(absoluteDir, file)
          removeGeneratedFile(filePath)
        }
      }
    }
  }

  // The default registries live in sibling Modules directories, not in
  // GeneratedModules. Remove only the generator-owned file, never an entire
  // handwritten Modules directory.
  for (const platform of ['ios', 'android', 'macos'] as const) {
    removeGeneratedFile(path.resolve(rootDir, registrationOutputPath(platform, options)))
  }
}

/**
 * Group platform implementations by their runtime module name.
 */
function groupBlocksByModule(blocks: NativeBlock[]): Map<string, NativeBlock[]> {
  const grouped = new Map<string, NativeBlock[]>()

  for (const block of blocks) {
    const moduleName = extractModuleName(block)
    const existing = grouped.get(moduleName) || []
    existing.push(block)
    grouped.set(moduleName, existing)
  }

  return grouped
}

function extractModuleName(block: NativeBlock): string {
  const swiftMatch = block.content.match(/var\s+moduleName\s*:\s*String\s*\{\s*"([^"]+)"\s*\}/)
  if (swiftMatch) return swiftMatch[1]

  const kotlinMatch = block.content.match(/override\s+val\s+moduleName\s*:\s*String\s*=\s*"([^"]+)"/)
  if (kotlinMatch) return kotlinMatch[1]

  // Validation normally prevents this fallback, but keep generation errors
  // deterministic for direct programmatic callers.
  return block.componentName
}

function toTypeScriptIdentifier(moduleName: string): string {
  const parts = moduleName.match(/[A-Za-z0-9_$]+/g) ?? ['NativeModule']
  let identifier = parts
    .map(part => part.length > 0 ? part[0].toUpperCase() + part.slice(1) : '')
    .join('')

  if (!/^[A-Za-z_$]/.test(identifier)) {
    identifier = `_${identifier}`
  }

  return identifier || 'NativeModule'
}
