import assert from 'node:assert/strict'
import { test } from 'node:test'
import {
  parseAdbDevices,
  parseDevicectlList,
  parseSimctlAvailableDevices,
} from '../host-probes.mjs'

test('parseSimctlAvailableDevices finds a shutdown iPhone under a runtime', () => {
  const output = `
== Devices ==
-- iOS 26.5 --
    iPhone 16 (AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE) (Shutdown)
    iPad Pro (11-inch) (FFFFFFFF-0000-1111-2222-333333333333) (Booted)
-- Unavailable: com.apple.CoreSimulator.SimRuntime.iOS-18-0 --
    iPhone 15 (FFFF-0000) (Shutdown)
`
  const devices = parseSimctlAvailableDevices(output)
  assert.equal(devices.length, 2)
  assert.equal(devices[0].name, 'iPhone 16')
  assert.equal(devices[0].state, 'Shutdown')
  assert.equal(devices[0].runtime, 'iOS 26.5')
})

test('parseDevicectlList marks only tunneled developer-mode devices reachable', () => {
  const payload = {
    result: {
      devices: [
        {
          identifier: 'phone',
          hardwareProperties: { udid: 'PHONE-UDID', marketingName: 'iPhone 16' },
          connectionProperties: { pairingState: 'paired', tunnelState: 'disconnected' },
          deviceProperties: { name: 'iPhone', developerModeStatus: 'enabled', osVersionNumber: '26.6' },
        },
        {
          identifier: 'pad',
          hardwareProperties: { udid: 'PAD-UDID', marketingName: 'iPad Pro' },
          connectionProperties: { pairingState: 'paired', tunnelState: 'connected' },
          deviceProperties: { name: 'iPad (2)', developerModeStatus: 'disabled' },
        },
        {
          identifier: 'ready',
          hardwareProperties: { udid: 'READY-UDID', marketingName: 'iPhone 16 Pro' },
          connectionProperties: { pairingState: 'paired', tunnelState: 'connected' },
          deviceProperties: { name: 'Ready', developerModeStatus: 'enabled' },
        },
      ],
    },
  }
  const devices = parseDevicectlList(JSON.stringify(payload))
  assert.equal(devices.filter(device => device.reachable).length, 2)
  assert.equal(devices.find(device => device.udid === 'READY-UDID').developerMode, 'enabled')
})

test('parseAdbDevices ignores the header and marks unauthorized phones not ready', () => {
  const output = `List of devices attached
emulator-5554          device product:sdk_gphone64
R5CT00                 unauthorized
`
  const devices = parseAdbDevices(output)
  assert.equal(devices.length, 2)
  assert.equal(devices[0].ready, true)
  assert.equal(devices[1].ready, false)
})
