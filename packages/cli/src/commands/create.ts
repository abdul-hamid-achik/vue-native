import { Command } from 'commander'
import { mkdir, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import pc from 'picocolors'

export const createCommand = new Command('create')
  .description('Create a new Vue Native project')
  .argument('<name>', 'project name')
  .action(async (name: string) => {
    const dir = join(process.cwd(), name)
    console.log(pc.cyan(`\nCreating Vue Native project: ${pc.bold(name)}\n`))

    try {
      await mkdir(dir, { recursive: true })
      await mkdir(join(dir, 'app'), { recursive: true })
      await mkdir(join(dir, 'app', 'pages'), { recursive: true })

      // package.json
      await writeFile(join(dir, 'package.json'), JSON.stringify({
        name,
        version: '0.0.1',
        private: true,
        type: 'module',
        scripts: {
          dev: 'vue-native dev',
          build: 'vite build',
          typecheck: 'tsc --noEmit',
        },
        dependencies: {
          '@vue-native/runtime': '^0.1.0',
          '@vue-native/navigation': '^0.1.0',
          'vue': '^3.5.0',
        },
        devDependencies: {
          '@vue-native/vite-plugin': '^0.1.0',
          '@vitejs/plugin-vue': '^5.0.0',
          'vite': '^6.1.0',
          'typescript': '^5.7.0',
        },
      }, null, 2))

      // vite.config.ts
      await writeFile(join(dir, 'vite.config.ts'), `import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueNative from '@vue-native/vite-plugin'

export default defineConfig({
  plugins: [vue(), vueNative()],
})
`)

      // tsconfig.json
      await writeFile(join(dir, 'tsconfig.json'), JSON.stringify({
        compilerOptions: {
          target: 'ES2020',
          module: 'ESNext',
          moduleResolution: 'bundler',
          strict: true,
          jsx: 'preserve',
          lib: ['ES2020'],
          types: [],
        },
        include: ['app/**/*'],
      }, null, 2))

      // app/main.ts
      await writeFile(join(dir, 'app', 'main.ts'), `import { createApp } from 'vue-native'
import { createRouter } from '@vue-native/navigation'
import App from './App.vue'
import Home from './pages/Home.vue'

const router = createRouter([
  { name: 'Home', component: Home },
])

const app = createApp(App)
app.use(router)
app.start()
`)

      // app/App.vue
      await writeFile(join(dir, 'app', 'App.vue'), `<template>
  <VSafeArea :style="{ flex: 1, backgroundColor: '#ffffff' }">
    <RouterView />
  </VSafeArea>
</template>

<script setup lang="ts">
import { RouterView } from '@vue-native/navigation'
</script>
`)

      // app/pages/Home.vue
      await writeFile(join(dir, 'app', 'pages', 'Home.vue'), `<template>
  <VView :style="styles.container">
    <VText :style="styles.title">Hello, Vue Native! 🎉</VText>
    <VText :style="styles.subtitle">Edit app/pages/Home.vue to get started.</VText>
    <VButton :style="styles.button" @press="count++">
      <VText :style="styles.buttonText">Count: {{ count }}</VText>
    </VButton>
  </VView>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { createStyleSheet } from 'vue-native'

const count = ref(0)

const styles = createStyleSheet({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1a1a1a',
    marginBottom: 8,
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
    marginBottom: 32,
  },
  button: {
    backgroundColor: '#4f46e5',
    paddingHorizontal: 32,
    paddingVertical: 14,
    borderRadius: 12,
  },
  buttonText: {
    color: '#ffffff',
    fontSize: 18,
    fontWeight: '600',
  },
})
</script>
`)

      console.log(pc.green('✓ Project created successfully!\n'))
      console.log(pc.white('Next steps:\n'))
      console.log(pc.white(`  cd ${name}`))
      console.log(pc.white('  bun install'))
      console.log(pc.white('  vue-native dev\n'))
      console.log(pc.dim('Then open your Xcode project and connect to the dev server for hot reload.\n'))
    } catch (err) {
      console.error(pc.red(`Error creating project: ${(err as Error).message}`))
      process.exit(1)
    }
  })
