import { program } from 'commander'
import { buildCommand } from './commands/build.js'
import { createCommand } from './commands/create.js'
import { devCommand } from './commands/dev.js'
import { runCommand } from './commands/run.js'
import { generateCommand } from './commands/generate.js'

program
  .name('vue-native')
  .description('Vue Native — build native iOS and Android apps with Vue.js')
  .version('0.1.0')

program.addCommand(buildCommand)
program.addCommand(createCommand)
program.addCommand(devCommand)
program.addCommand(runCommand)
program.addCommand(generateCommand)

program.parse(process.argv)
