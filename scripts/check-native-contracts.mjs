import { readdir, readFile } from 'node:fs/promises'
import { join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(fileURLToPath(new URL('..', import.meta.url)))
const composablesDir = join(root, 'packages/runtime/src/composables')

const platforms = {
  android: {
    extension: '.kt',
    intentionalOmissions: new Map([
      ['DragDrop', 'Desktop-only drag-and-drop integration.'],
      ['FileDialog', 'Desktop-only native file picker integration.'],
      ['Menu', 'Desktop-only application and context menu integration.'],
      ['Window', 'Desktop-only window management integration.'],
    ]),
    registry: join(root, 'native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/Modules/NativeModuleRegistry.kt'),
    moduleDirs: [
      join(root, 'native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/Modules'),
    ],
  },
  ios: {
    extension: '.swift',
    intentionalOmissions: new Map([
      ['BackHandler', 'Android-only system back-button integration.'],
      ['DragDrop', 'Desktop-only drag-and-drop integration.'],
      ['FileDialog', 'Desktop-only native file picker integration.'],
      ['Http', 'Certificate pinning is exposed by the JavaScript fetch polyfill on Apple platforms.'],
      ['Menu', 'Desktop-only application and context menu integration.'],
      ['Window', 'Desktop-only window management integration.'],
    ]),
    registry: join(root, 'native/ios/VueNativeCore/Sources/VueNativeCore/Modules/NativeModuleRegistry.swift'),
    moduleDirs: [
      join(root, 'native/ios/VueNativeCore/Sources/VueNativeCore/Modules'),
    ],
  },
  macos: {
    extension: '.swift',
    intentionalOmissions: new Map([
      ['BackHandler', 'Android-only system back-button integration.'],
      ['BackgroundTask', 'Background task scheduling is currently mobile-only.'],
      ['Bluetooth', 'Bluetooth support is currently mobile-only.'],
      ['Calendar', 'Calendar support is currently mobile-only.'],
      ['Contacts', 'Contacts support is currently mobile-only.'],
      ['Http', 'Certificate pinning is exposed by the JavaScript fetch polyfill on Apple platforms.'],
      ['IAP', 'In-app purchases are currently mobile-only.'],
      ['OTA', 'Over-the-air bundle updates are currently mobile-only.'],
      ['Sensors', 'Motion sensor support is currently mobile-only.'],
      ['SocialAuth', 'Platform social sign-in providers are currently mobile-only.'],
    ]),
    registry: join(root, 'native/macos/VueNativeMacOS/Sources/VueNativeMacOS/Modules/NativeModuleRegistry.swift'),
    moduleDirs: [
      join(root, 'native/macos/VueNativeMacOS/Sources/VueNativeMacOS/Modules'),
      join(root, 'native/shared/VueNativeShared/Sources/VueNativeShared/Modules'),
    ],
  },
}

async function runtimeCalls() {
  const calls = new Map()
  const files = (await readdir(composablesDir)).filter(file => file.endsWith('.ts'))

  for (const file of files) {
    const source = await readFile(join(composablesDir, file), 'utf8')
    const invocation = /invokeNativeModule\(\s*(['"])([^'"]+)\1\s*,\s*(['"])([^'"]+)\3/g
    for (const match of source.matchAll(invocation)) {
      const [, , moduleName, , methodName] = match
      const methods = calls.get(moduleName) ?? new Set()
      methods.add(methodName)
      calls.set(moduleName, methods)
    }
  }

  return calls
}

async function findModuleSource(moduleName, platform) {
  const filename = `${moduleName}Module${platform.extension}`
  for (const directory of platform.moduleDirs) {
    try {
      return await readFile(join(directory, filename), 'utf8')
    } catch (error) {
      if (error?.code !== 'ENOENT') throw error
    }
  }
  return null
}

function dispatchLabels(source, extension) {
  const labels = new Set()
  for (const line of source.split('\n')) {
    const trimmed = line.trim()
    const isDispatch = extension === '.kt'
      ? trimmed.includes('->')
      : trimmed.startsWith('case ') && trimmed.includes(':')
    if (!isDispatch) continue

    for (const match of trimmed.matchAll(/"([^"]+)"/g)) {
      labels.add(match[1])
    }
  }
  return labels
}

const calls = await runtimeCalls()
const missing = []

for (const [platformName, platform] of Object.entries(platforms)) {
  const registry = await readFile(platform.registry, 'utf8')
  for (const [moduleName, methods] of calls) {
    const source = await findModuleSource(moduleName, platform)
    const omissionReason = platform.intentionalOmissions.get(moduleName)

    if (source === null) {
      if (omissionReason === undefined) {
        missing.push(`${platformName}: ${moduleName} implementation is missing and is not an intentional omission`)
      }
      continue
    }

    if (omissionReason !== undefined) {
      missing.push(`${platformName}: ${moduleName} has an implementation; remove its stale intentional omission (${omissionReason})`)
    }

    const className = `${moduleName}Module`
    if (!new RegExp(`\\b${className}\\s*\\(`).test(registry)) {
      missing.push(`${platformName}: ${moduleName} implementation is not registered`)
      continue
    }

    const labels = dispatchLabels(source, platform.extension)
    for (const methodName of methods) {
      if (!labels.has(methodName)) {
        missing.push(`${platformName}: ${moduleName}.${methodName}`)
      }
    }
  }

  for (const [moduleName, reason] of platform.intentionalOmissions) {
    if (!calls.has(moduleName)) {
      missing.push(`${platformName}: ${moduleName} intentional omission is stale because the runtime no longer invokes it (${reason})`)
    }
    if (reason.trim().length === 0) {
      missing.push(`${platformName}: ${moduleName} intentional omission must include a reason`)
    }
  }
}

if (missing.length > 0) {
  console.error('Native module contract drift detected:')
  for (const contract of missing) console.error(`  - ${contract}`)
  process.exitCode = 1
} else {
  process.stdout.write('Native module dispatch contracts match the runtime calls.\n')
}
