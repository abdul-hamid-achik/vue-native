import { Command } from 'commander'
import { existsSync } from 'node:fs'
import { join } from 'node:path'
import pc from 'picocolors'
import { p } from '../ui.js'
import { parseDirectory } from '@thelacanians/vue-native-sfc-parser'
import { generateCode, commitGeneratedFiles, validateNativeBlocks, formatValidationErrors } from '@thelacanians/vue-native-codegen'
import type { CodegenOptions } from '@thelacanians/vue-native-codegen'
import { ConfigError } from '../config.js'

export const generateCommand = new Command('generate')
  .description('Generate native code from <native> blocks in Vue SFC files')
  .option('--root <path>', 'project root directory', process.cwd())
  .option('--watch', 'watch mode - regenerate on file changes')
  .option('--clean', 'clean generated files before generating')
  .option('--ios-output <path>', 'iOS Swift output directory')
  .option('--android-output <path>', 'Android Kotlin output directory')
  .option('--macos-output <path>', 'macOS Swift output directory')
  .option('--ts-output <path>', 'TypeScript output directory')
  .option('--no-swift', 'disable Swift generation')
  .option('--no-kotlin', 'disable Kotlin generation')
  .option('--no-typescript', 'disable TypeScript generation')
  .option('--exclude <patterns>', 'patterns to exclude (comma-separated)')
  .action(async (options: {
    root: string
    watch?: boolean
    clean?: boolean
    iosOutput?: string
    androidOutput?: string
    macosOutput?: string
    tsOutput?: string
    swift?: boolean
    kotlin?: boolean
    typescript?: boolean
    exclude?: string
  }) => {
    const cwd = options.root
    const appDir = join(cwd, 'app')

    // Check if app directory exists
    if (!existsSync(appDir)) {
      throw new ConfigError(
        `App directory not found at ${appDir}. Make sure you run this command from your project root.`,
      )
    }

    // Build codegen options
    const codegenOptions: CodegenOptions = {
      root: cwd,
      includeHeader: true,
      generateSwift: options.swift !== false,
      generateKotlin: options.kotlin !== false,
      generateTypeScript: options.typescript !== false,
    }

    if (options.iosOutput) codegenOptions.iosOutputDir = options.iosOutput
    if (options.androidOutput) codegenOptions.androidOutputDir = options.androidOutput
    if (options.macosOutput) codegenOptions.macosOutputDir = options.macosOutput
    if (options.tsOutput) codegenOptions.typescriptOutputDir = options.tsOutput

    // Parse exclude patterns
    const exclude = options.exclude
      ? options.exclude.split(',').map(p => p.trim())
      : ['node_modules', 'dist', '.git', '.turbo']

    /**
     * Run code generation
     */
    async function runGeneration() {
      p.intro(pc.cyan('Vue Native Code Generator'))

      try {
        // Parse SFCs
        p.log.step('Scanning SFC files...')
        const parseResult = parseDirectory('.', {
          root: cwd,
          exclude,
        })

        if (parseResult.errors.length > 0) {
          const details = parseResult.errors
            .map(err => `  - ${err.file}:${err.line || '?'} ${err.message}`)
            .join('\n')
          throw new ConfigError(`Native block parse failed:\n${details}`)
        }

        const blockCount = parseResult.allNativeBlocks.length
        p.log.success(`Found ${blockCount} <native> block${blockCount !== 1 ? 's' : ''}`)

        if (blockCount === 0) {
          p.log.warn('No <native> blocks found.')
          p.log.info('Removing stale generated modules and writing empty registries.')
        }

        // Validate native blocks
        p.log.step('Validating native code...')
        const validation = validateNativeBlocks(parseResult.allNativeBlocks)

        if (!validation.isValid) {
          p.log.error('Validation failed:')
          console.log(formatValidationErrors(validation))
          throw new ConfigError('Validation failed')
        }

        if (validation.warnings.length > 0) {
          p.log.warn(`${validation.warnings.length} warning${validation.warnings.length !== 1 ? 's' : ''}`)
        } else {
          p.log.success('Validation passed')
        }

        // Group by platform
        const iosBlocks = parseResult.allNativeBlocks.filter(b => b.platform === 'ios' || b.platform === 'macos')
        const androidBlocks = parseResult.allNativeBlocks.filter(b => b.platform === 'android')

        const platformSummary: string[] = []
        if (iosBlocks.length > 0) {
          platformSummary.push(`iOS/macOS: ${iosBlocks.length} block${iosBlocks.length !== 1 ? 's' : ''}`)
        }
        if (androidBlocks.length > 0) {
          platformSummary.push(`Android: ${androidBlocks.length} block${androidBlocks.length !== 1 ? 's' : ''}`)
        }
        if (platformSummary.length > 0) {
          p.log.info(platformSummary.join('\n'))
        }

        // Generate code
        p.log.step('Generating code...')
        const codegenResult = generateCode(parseResult.allNativeBlocks, codegenOptions)

        if (codegenResult.errors.length > 0) {
          p.log.error(`Generation errors:\n${codegenResult.errors.map(err => `  - ${err.file} ${err.message}`).join('\n')}`)
          throw new ConfigError('Code generation failed')
        }

        // Replace only generator-owned files after validation has succeeded.
        // This prunes modules removed from an SFC and guarantees the registry
        // cannot retain references to a deleted generated class.
        if (options.clean) {
          p.log.info('Stale generated files will be pruned after a successful write.')
        }

        p.log.step('Writing files...')
        const writeResult = commitGeneratedFiles(codegenResult, cwd, codegenOptions)

        if (writeResult.errors.length > 0) {
          p.log.error(`Write errors:\n${writeResult.errors.map(err => `  - ${err.message}`).join('\n')}`)
          throw new ConfigError('Failed to write generated files')
        }

        // Summary
        p.log.success('Generation complete!')
        p.note(
          [
            `Swift:      ${codegenResult.stats.swiftFiles} file${codegenResult.stats.swiftFiles !== 1 ? 's' : ''}`,
            `Kotlin:     ${codegenResult.stats.kotlinFiles} file${codegenResult.stats.kotlinFiles !== 1 ? 's' : ''}`,
            `TypeScript: ${codegenResult.stats.typescriptFiles} file${codegenResult.stats.typescriptFiles !== 1 ? 's' : ''}`,
          ].join('\n'),
          'Generated files',
        )

        if (codegenResult.warnings.length > 0) {
          p.log.warn(`Warnings:\n${codegenResult.warnings.map(warn => `  - ${warn.message}`).join('\n')}`)
        }

        p.outro('Ready to build!')
      } catch (error) {
        if (error instanceof ConfigError) throw error
        throw new ConfigError(
          (error as Error).message || 'Unknown generation error',
        )
      }
    }

    // Run generation
    await runGeneration()

    // Watch mode
    if (options.watch) {
      p.log.info('Watch mode enabled. Press Ctrl+C to stop.')

      const chokidar = await import('chokidar')
      const watcher = chokidar.default.watch('app/**/*.vue', {
        cwd,
        ignored: exclude,
        ignoreInitial: true,
      })

      watcher.on('change', async (file) => {
        console.log(pc.dim(`[${new Date().toLocaleTimeString()}]`) + pc.blue(` Changed: ${file}`))
        await runGeneration()
      })

      watcher.on('error', (error) => {
        console.error(pc.red('Watch error:'), error)
      })

      // Handle shutdown
      process.on('SIGINT', () => {
        console.log(pc.yellow('\n⏹️  Stopping watch mode...'))
        watcher.close()
        process.exit(0)
      })

      // Keep process alive
      await new Promise(() => {})
    }
  })
