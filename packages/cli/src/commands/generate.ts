import { Command } from 'commander'
import { existsSync } from 'node:fs'
import { join } from 'node:path'
import pc from 'picocolors'
import { parseDirectory } from '@thelacanians/vue-native-sfc-parser'
import { generateCode, writeGeneratedFiles, cleanGeneratedFiles, validateNativeBlocks, formatValidationErrors } from '@thelacanians/vue-native-codegen'
import type { CodegenOptions } from '@thelacanians/vue-native-codegen'

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
      console.error(pc.red(`Error: App directory not found at ${appDir}`))
      console.error(pc.yellow('Make sure you run this command from your project root.'))
      process.exit(1)
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
      console.log(pc.cyan('\n🔧 Vue Native Code Generator'))
      console.log(pc.dim('─────────────────────────────────────\n'))

      try {
        // Clean if requested
        if (options.clean) {
          console.log(pc.yellow('🗑️  Cleaning generated files...'))
          cleanGeneratedFiles(codegenOptions, cwd)
          console.log(pc.green('✓ Cleaned\n'))
        }

        // Parse SFCs
        console.log(pc.blue('📄 Scanning SFC files...'))
        const parseResult = parseDirectory('.', {
          root: cwd,
          exclude,
        })

        if (parseResult.errors.length > 0) {
          console.log(pc.yellow('⚠️  Parse warnings:'))
          parseResult.errors.forEach((err) => {
            console.log(pc.dim(`  - ${err.file}:${err.line || '?'} ${err.message}`))
          })
          console.log()
        }

        const blockCount = parseResult.allNativeBlocks.length
        console.log(pc.green(`✓ Found ${blockCount} <native> block${blockCount !== 1 ? 's' : ''}`))

        if (blockCount === 0) {
          console.log(pc.yellow('\n⚠️  No <native> blocks found.'))
          console.log(pc.dim('Add <native platform="ios"> or <native platform="android"> blocks to your SFC files.'))
          return
        }

        // Validate native blocks
        console.log(pc.blue('🔍 Validating native code...'))
        const validation = validateNativeBlocks(parseResult.allNativeBlocks)

        if (!validation.isValid) {
          console.log(pc.red('\n❌ Validation failed:'))
          console.log(formatValidationErrors(validation))
          process.exit(1)
        }

        if (validation.warnings.length > 0) {
          console.log(pc.yellow(`⚠️  ${validation.warnings.length} warning${validation.warnings.length !== 1 ? 's' : ''}`))
        } else {
          console.log(pc.green('✓ Validation passed'))
        }
        console.log()

        // Group by platform
        const iosBlocks = parseResult.allNativeBlocks.filter(b => b.platform === 'ios' || b.platform === 'macos')
        const androidBlocks = parseResult.allNativeBlocks.filter(b => b.platform === 'android')

        if (iosBlocks.length > 0) {
          console.log(pc.dim(`  - iOS/macOS: ${iosBlocks.length} block${iosBlocks.length !== 1 ? 's' : ''}`))
        }
        if (androidBlocks.length > 0) {
          console.log(pc.dim(`  - Android: ${androidBlocks.length} block${androidBlocks.length !== 1 ? 's' : ''}`))
        }
        console.log()

        // Generate code
        console.log(pc.blue('⚙️  Generating code...'))
        const codegenResult = generateCode(parseResult.allNativeBlocks, codegenOptions)

        if (codegenResult.errors.length > 0) {
          console.log(pc.red('\n❌ Generation errors:'))
          codegenResult.errors.forEach((err) => {
            console.log(pc.red(`  - ${err.file} ${err.message}`))
          })
          process.exit(1)
        }

        // Write files
        console.log(pc.blue('📝 Writing files...'))
        const writeResult = writeGeneratedFiles(codegenResult, cwd)

        if (writeResult.errors.length > 0) {
          console.log(pc.red('\n❌ Write errors:'))
          writeResult.errors.forEach((err) => {
            console.log(pc.red(`  - ${err.message}`))
          })
          process.exit(1)
        }

        // Summary
        console.log(pc.green('\n✅ Generation complete!\n'))
        console.log(pc.dim('Generated files:'))
        console.log(pc.dim(`  - Swift:      ${codegenResult.stats.swiftFiles} file${codegenResult.stats.swiftFiles !== 1 ? 's' : ''}`))
        console.log(pc.dim(`  - Kotlin:     ${codegenResult.stats.kotlinFiles} file${codegenResult.stats.kotlinFiles !== 1 ? 's' : ''}`))
        console.log(pc.dim(`  - TypeScript: ${codegenResult.stats.typescriptFiles} file${codegenResult.stats.typescriptFiles !== 1 ? 's' : ''}`))
        console.log()

        if (codegenResult.warnings.length > 0) {
          console.log(pc.yellow('⚠️  Warnings:'))
          codegenResult.warnings.forEach((warn) => {
            console.log(pc.dim(`  - ${warn.message}`))
          })
          console.log()
        }

        console.log(pc.green('🎉 Ready to build!\n'))
      } catch (error) {
        console.error(pc.red('\n❌ Fatal error:'))
        console.error(pc.red((error as Error).message))
        console.error(pc.dim((error as Error).stack || ''))
        process.exit(1)
      }
    }

    // Run generation
    await runGeneration()

    // Watch mode
    if (options.watch) {
      console.log(pc.cyan('\n👁️  Watch mode enabled. Press Ctrl+C to stop.\n'))

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
