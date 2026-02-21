import { Command } from 'commander'
import { spawn, execSync } from 'node:child_process'
import { existsSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import pc from 'picocolors'

export const runCommand = new Command('run')
  .description('Build and run the app')
  .argument('<platform>', 'platform to run on (ios)')
  .option('--device', 'run on physical device instead of simulator')
  .option('--scheme <scheme>', 'Xcode scheme to build')
  .option('--simulator <name>', 'simulator name', 'iPhone 16')
  .action(async (platform: string, options: { device?: boolean; scheme?: string; simulator: string }) => {
    if (platform !== 'ios') {
      console.error(pc.red('Only "ios" platform is supported currently'))
      process.exit(1)
    }

    const cwd = process.cwd()
    console.log(pc.cyan('\n📱 Vue Native — Run iOS\n'))

    // Step 1: Build the JS bundle
    console.log(pc.white('  Building JS bundle...'))
    try {
      execSync('bun run vite build', { cwd, stdio: 'inherit' })
      console.log(pc.green('  ✓ Bundle built\n'))
    } catch {
      console.error(pc.red('  ✗ Bundle build failed'))
      process.exit(1)
    }

    // Step 2: Find Xcode project
    let xcodeProject: string | null = null
    const iosDir = join(cwd, 'ios')

    if (existsSync(iosDir)) {
      // Look for .xcworkspace first (CocoaPods), then .xcodeproj
      for (const ext of ['.xcworkspace', '.xcodeproj']) {
        try {
          const entries = readdirSync(iosDir)
          const match = entries.find(e => e.endsWith(ext))
          if (match) {
            xcodeProject = join(iosDir, match)
            break
          }
        } catch {}
      }
    }

    if (!xcodeProject) {
      console.log(pc.yellow('  No Xcode project found in ./ios/'))
      console.log(pc.dim('  To add iOS support, create an Xcode project in the ios/ directory.'))
      console.log(pc.dim('  Bundle has been built to dist/vue-native-bundle.js\n'))
      return
    }

    // Step 3: Build with xcodebuild
    const isWorkspace = xcodeProject.endsWith('.xcworkspace')
    const scheme = options.scheme || xcodeProject.split('/').pop()?.replace(/\.(xcworkspace|xcodeproj)$/, '') || 'App'
    const destination = options.device
      ? 'generic/platform=iOS'
      : `platform=iOS Simulator,name=${options.simulator}`

    const projectFlag = isWorkspace ? '-workspace' : '-project'

    console.log(pc.white(`  Building ${scheme} for ${options.device ? 'device' : options.simulator}...`))

    const xcodebuild = spawn(
      'xcodebuild',
      [projectFlag, xcodeProject, '-scheme', scheme, '-destination', destination, 'build'],
      {
        cwd,
        stdio: 'pipe',
        env: { ...process.env, DEVELOPER_DIR: '/Applications/Xcode.app/Contents/Developer' },
      }
    )

    xcodebuild.stderr?.on('data', (data: Buffer) => {
      const text = data.toString().trim()
      if (text.includes('error:') || text.includes('warning:')) {
        console.log(pc.dim(`  ${text}`))
      }
    })

    xcodebuild.on('close', (code) => {
      if (code === 0) {
        console.log(pc.green('  ✓ Build successful\n'))
      } else {
        console.error(pc.red(`  ✗ Build failed (exit code ${code})`))
      }
    })
  })
