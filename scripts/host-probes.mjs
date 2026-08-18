import { execFileSync } from 'node:child_process'
import { existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

export function runCapture(command, args, options = {}) {
  try {
    return {
      ok: true,
      stdout: execFileSync(command, args, {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'pipe'],
        ...options,
      }),
    }
  } catch (error) {
    return {
      ok: false,
      stdout: `${error.stdout ?? ''}${error.stderr ?? ''}`,
      error: error.message,
    }
  }
}

export function parseSimctlAvailableDevices(output) {
  const devices = []
  let runtime = null
  for (const line of output.split('\n')) {
    const runtimeMatch = line.match(/^--\s+(.+?)\s+--$/)
    if (runtimeMatch) {
      runtime = runtimeMatch[1]
      continue
    }
    const deviceMatch = line.match(/^\s+(.+?)\s+\(([0-9A-Fa-f-]{36})\)\s+\((Booted|Shutdown)\)/)
    if (!deviceMatch || !runtime) continue
    devices.push({
      name: deviceMatch[1].trim(),
      udid: deviceMatch[2],
      state: deviceMatch[3],
      runtime,
    })
  }
  return devices
}

export function parseDevicectlList(output) {
  let parsed
  try {
    parsed = JSON.parse(output)
  } catch {
    return []
  }
  const devices = parsed?.result?.devices ?? []
  return devices.map((device) => {
    const hardware = device.hardwareProperties ?? {}
    const connection = device.connectionProperties ?? {}
    const properties = device.deviceProperties ?? {}
    return {
      name: properties.name ?? hardware.marketingName ?? device.identifier,
      udid: hardware.udid ?? device.identifier,
      model: hardware.marketingName ?? hardware.productType ?? 'unknown',
      osVersion: properties.osVersionNumber ?? null,
      pairingState: connection.pairingState ?? 'unknown',
      tunnelState: connection.tunnelState ?? 'unknown',
      transportType: connection.transportType ?? null,
      developerMode: properties.developerModeStatus ?? 'unknown',
      lastConnectionDate: connection.lastConnectionDate ?? null,
      reachable: connection.tunnelState === 'connected',
    }
  })
}

export function parseAdbDevices(output) {
  const devices = []
  for (const line of output.split('\n').slice(1)) {
    const match = line.match(/^(\S+)\s+(\S+)/)
    if (!match || match[1] === 'List') continue
    devices.push({ serial: match[1], state: match[2], ready: match[2] === 'device' })
  }
  return devices
}

export function probeIosSimulators() {
  if (process.platform !== 'darwin') {
    return { available: [], skipReason: 'Host is not macOS' }
  }
  const listed = runCapture('xcrun', ['simctl', 'list', 'devices', 'available'])
  if (!listed.ok) {
    return { available: [], skipReason: `xcrun simctl failed: ${listed.error}` }
  }
  const available = parseSimctlAvailableDevices(listed.stdout)
  const iphone = available.find(device => device.name === 'iPhone 17')
    ?? available.find(device => /^iPhone 17/.test(device.name))
    ?? available.find(device => /iPhone/i.test(device.name))
  if (!iphone) {
    return { available, skipReason: 'No available iOS Simulator runtime' }
  }
  return { available, destination: `platform=iOS Simulator,id=${iphone.udid}` }
}

export function probeIosDevices() {
  if (process.platform !== 'darwin') {
    return { devices: [], skipReason: 'Host is not macOS' }
  }
  const tempDir = mkdtempSync(join(tmpdir(), 'vue-native-devicectl-'))
  const jsonPath = join(tempDir, 'devices.json')
  const listed = runCapture('xcrun', ['devicectl', 'list', 'devices', '--json-output', jsonPath])
  let devices = []
  try {
    if (listed.ok && existsSync(jsonPath)) {
      devices = parseDevicectlList(readFileSync(jsonPath, 'utf8'))
    }
  } finally {
    rmSync(tempDir, { recursive: true, force: true })
  }
  const reachable = devices.filter(device => device.reachable && device.developerMode === 'enabled')
  if (reachable.length === 0) {
    const details = devices.map((device) => {
      const bits = [
        device.name,
        device.model,
        `tunnel=${device.tunnelState}`,
        `developerMode=${device.developerMode}`,
      ]
      return bits.join(' ')
    })
    return {
      devices,
      skipReason: details.length > 0
        ? `No reachable iOS device with Developer Mode enabled (${details.join('; ')})`
        : listed.error ?? 'No paired iOS devices',
    }
  }
  return { devices, destination: `platform=iOS,id=${reachable[0].udid}` }
}

export function probeAndroidDevices() {
  const adb = process.env.ANDROID_HOME
    ? `${process.env.ANDROID_HOME}/platform-tools/adb`
    : 'adb'
  const command = existsSync(adb) ? adb : 'adb'
  const listed = runCapture(command, ['devices', '-l'])
  if (!listed.ok) {
    return { devices: [], skipReason: 'adb is not available (ANDROID_HOME unset and adb not on PATH)' }
  }
  const devices = parseAdbDevices(listed.stdout)
  const ready = devices.filter(device => device.ready)
  if (ready.length === 0) {
    return {
      devices,
      skipReason: devices.length > 0
        ? `No ready Android device (${devices.map(device => `${device.serial}:${device.state}`).join(', ')})`
        : 'No Android devices attached',
    }
  }
  return { devices, serial: ready[0].serial }
}

export function iosSimulatorDestination(probe = probeIosSimulators()) {
  return probe.destination ?? 'platform=iOS Simulator,name=iPhone 17,OS=latest'
}
