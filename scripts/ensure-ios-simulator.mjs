import { execFileSync } from 'node:child_process'
import { probeIosSimulators } from './host-probes.mjs'

const probed = probeIosSimulators()
if (probed.destination) {
  process.stdout.write(`iOS Simulator already available: ${probed.destination}\n`)
  process.exit(0)
}

process.stdout.write(`${probed.skipReason ?? 'No iOS Simulator runtime'}\n`)
process.stdout.write('Downloading the iOS Simulator runtime via xcodebuild...\n')
execFileSync('xcodebuild', ['-downloadPlatform', 'iOS'], { stdio: 'inherit' })

const deviceTypes = execFileSync('xcrun', ['simctl', 'list', 'devicetypes'], { encoding: 'utf8' })
const typeMatch = deviceTypes.match(/iPhone 17 \(([^\)]+)\)/)
  ?? deviceTypes.match(/iPhone 16 \(([^\)]+)\)/)
  ?? deviceTypes.match(/iPhone[^\n]*\(([^\)]+)\)/)
if (!typeMatch) {
  process.stderr.write('No iPhone device type is registered after the runtime download.\n')
  process.exit(1)
}
const created = execFileSync(
  'xcrun',
  ['simctl', 'create', 'Vue Native iPhone', typeMatch[1]],
  { encoding: 'utf8' },
).trim()
process.stdout.write(`Created simulator ${created} from ${typeMatch[1]}\n`)

const after = probeIosSimulators()
if (!after.destination) {
  process.stderr.write(`${after.skipReason ?? 'Simulator still missing after download'}\n`)
  process.exit(1)
}
process.stdout.write(`Ready: ${after.destination}\n`)
