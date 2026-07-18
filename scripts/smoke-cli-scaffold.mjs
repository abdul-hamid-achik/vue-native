import { execFileSync } from 'node:child_process'
import {
  existsSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs'
import { tmpdir } from 'node:os'
import { basename, join, resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const cliDir = join(root, 'packages', 'cli')
const tempRoot = mkdtempSync(join(tmpdir(), 'vue-native-cli-smoke-'))
const packageDirs = {
  '@thelacanians/vue-native-runtime': join(root, 'packages', 'runtime'),
  '@thelacanians/vue-native-navigation': join(root, 'packages', 'navigation'),
  '@thelacanians/vue-native-sfc-parser': join(root, 'packages', 'sfc-parser'),
  '@thelacanians/vue-native-codegen': join(root, 'packages', 'codegen'),
  '@thelacanians/vue-native-vite-plugin': join(root, 'packages', 'vite-plugin'),
  '@thelacanians/vue-native-cli': cliDir,
}

function run(command, args, cwd) {
  execFileSync(command, args, {
    cwd,
    stdio: 'inherit',
    env: { ...process.env, CI: '1' },
  })
}

try {
  const archives = {}
  for (const [packageName, packageDir] of Object.entries(packageDirs)) {
    const manifest = JSON.parse(readFileSync(join(packageDir, 'package.json'), 'utf8'))
    run('bun', ['pm', 'pack', '--destination', tempRoot], packageDir)
    const archiveName = `${packageName.replace('@', '').replace('/', '-')}-${manifest.version}.tgz`
    const archivePath = join(tempRoot, archiveName)
    if (!existsSync(archivePath)) {
      throw new Error(`Packed archive was not created at ${archivePath}`)
    }
    archives[packageName] = archivePath
  }

  run('bun', ['init', '-y'], tempRoot)
  const installerManifestPath = join(tempRoot, 'package.json')
  const installerManifest = JSON.parse(readFileSync(installerManifestPath, 'utf8'))
  const packedArchive = packageName => `file:./${basename(archives[packageName])}`
  const packedDependencies = Object.fromEntries(
    Object.keys(packageDirs).map(packageName => [packageName, packedArchive(packageName)]),
  )
  installerManifest.dependencies = packedDependencies
  installerManifest.overrides = packedDependencies
  writeFileSync(installerManifestPath, `${JSON.stringify(installerManifest, null, 2)}\n`)
  run('bun', ['install'], tempRoot)

  const cli = join(tempRoot, 'node_modules', '.bin', 'vue-native')
  run(cli, ['create', 'smoke-app'], tempRoot)

  const app = join(tempRoot, 'smoke-app')
  const appManifestPath = join(app, 'package.json')
  const appManifest = JSON.parse(readFileSync(appManifestPath, 'utf8'))
  const localArchive = packageName => `file:../${basename(archives[packageName])}`
  appManifest.dependencies['@thelacanians/vue-native-runtime'] = localArchive('@thelacanians/vue-native-runtime')
  appManifest.dependencies['@thelacanians/vue-native-navigation'] = localArchive('@thelacanians/vue-native-navigation')
  appManifest.devDependencies['@thelacanians/vue-native-cli'] = localArchive('@thelacanians/vue-native-cli')
  appManifest.devDependencies['@thelacanians/vue-native-vite-plugin'] = localArchive('@thelacanians/vue-native-vite-plugin')
  appManifest.devDependencies['@thelacanians/vue-native-codegen'] = localArchive('@thelacanians/vue-native-codegen')
  appManifest.devDependencies['@thelacanians/vue-native-sfc-parser'] = localArchive('@thelacanians/vue-native-sfc-parser')
  appManifest.overrides = Object.fromEntries(
    Object.keys(packageDirs).map(packageName => [packageName, localArchive(packageName)]),
  )
  writeFileSync(appManifestPath, `${JSON.stringify(appManifest, null, 2)}\n`)

  const projectSpec = readFileSync(join(app, 'ios', 'project.yml'), 'utf8')
  if (!projectSpec.includes('path: ../native/ios/VueNativeCore')) {
    throw new Error('Fresh iOS project is not linked to its generated local Swift package')
  }
  if (!projectSpec.includes('path: ../dist/vue-native-bundle.js')
    || !projectSpec.includes('buildPhase: resources')) {
    throw new Error('Fresh iOS project does not copy the JavaScript bundle as an Xcode resource')
  }
  for (const relativePath of [
    ['native', 'ios', 'VueNativeCore', 'Tests', 'VueNativeCoreTests'],
    ['native', 'shared', 'VueNativeShared', 'Tests', 'VueNativeSharedTests'],
  ]) {
    const testTarget = join(app, ...relativePath)
    if (!existsSync(testTarget)) {
      throw new Error(`Bundled Swift package declares a missing test target: ${testTarget}`)
    }
  }

  run('bun', ['install'], app)
  for (const [packageName, packageDir] of Object.entries(packageDirs)) {
    const entry = packageName.endsWith('-cli') ? 'cli.js' : 'index.js'
    const builtEntry = readFileSync(join(packageDir, 'dist', entry))
    const installedEntry = readFileSync(join(app, 'node_modules', ...packageName.split('/'), 'dist', entry))
    if (!builtEntry.equals(installedEntry)) {
      throw new Error(`Fresh scaffold did not install the current ${packageName} tarball`)
    }
  }
  run('bun', ['run', 'typecheck'], app)
  run('bun', ['run', 'build'], app)

  process.stdout.write('Packed CLI fresh-scaffold smoke passed.\n')
} finally {
  rmSync(tempRoot, { recursive: true, force: true })
}
