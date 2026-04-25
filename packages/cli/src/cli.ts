import { program } from 'commander'
import pc from 'picocolors'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { buildCommand } from './commands/build.js'
import { createCommand } from './commands/create.js'
import { devCommand } from './commands/dev.js'
import { runCommand } from './commands/run.js'
import { generateCommand } from './commands/generate.js'
import { ConfigError } from './config.js'

const cliDir = dirname(fileURLToPath(import.meta.url))
const pkg = JSON.parse(readFileSync(join(cliDir, '..', 'package.json'), 'utf8'))

program
  .name('vue-native')
  .description('Vue Native — build native iOS and Android apps with Vue.js')
  .version(pkg.version)

program.addCommand(buildCommand)
program.addCommand(createCommand)
program.addCommand(devCommand)
program.addCommand(runCommand)
program.addCommand(generateCommand)

program.parseAsync(process.argv).catch((err) => {
  if (err instanceof ConfigError) {
    console.error(pc.red(err.message))
    process.exit(1)
  }
  throw err
})
