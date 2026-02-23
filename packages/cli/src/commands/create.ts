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
      await writeFile(join(dir, 'app', 'main.ts'), `import { createApp } from 'vue'
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
import { createStyleSheet } from 'vue'

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

      // ── iOS native project ──────────────────────────────────
      const iosDir = join(dir, 'ios')
      const iosSrcDir = join(iosDir, 'Sources')
      await mkdir(iosSrcDir, { recursive: true })

      // ios/project.yml (XcodeGen spec)
      const xcodeProjectName = name.replace(/[^a-zA-Z0-9]/g, '')
      const bundleId = `com.vuenative.${name.replace(/[^a-zA-Z0-9]/g, '').toLowerCase()}`
      await writeFile(join(iosDir, 'project.yml'), `name: ${xcodeProjectName}
options:
  bundleIdPrefix: com.vuenative
  deploymentTarget:
    iOS: "16.0"
  xcodeVersion: "15.0"

packages:
  VueNativeCore:
    path: ../native/ios

targets:
  ${xcodeProjectName}:
    type: application
    platform: iOS
    sources:
      - Sources
    dependencies:
      - package: VueNativeCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: ${bundleId}
        INFOPLIST_FILE: Sources/Info.plist
        SWIFT_VERSION: "5.9"
        GENERATE_INFOPLIST_FILE: false
    resources:
      - path: ../dist/vue-native-bundle.js
        optional: true
`)

      // ios/Sources/Info.plist
      await writeFile(join(iosSrcDir, 'Info.plist'), `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${name}</string>
  <key>CFBundleExecutable</key>
  <string>$(EXECUTABLE_NAME)</string>
  <key>CFBundleIdentifier</key>
  <string>${bundleId}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$(PRODUCT_NAME)</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSRequiresIPhoneOS</key>
  <true/>
  <key>UIApplicationSceneManifest</key>
  <dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <false/>
    <key>UISceneConfigurations</key>
    <dict>
      <key>UIWindowSceneSessionRoleApplication</key>
      <array>
        <dict>
          <key>UISceneConfigurationName</key>
          <string>Default Configuration</string>
          <key>UISceneDelegateClassName</key>
          <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
        </dict>
      </array>
    </dict>
  </dict>
  <key>UILaunchScreen</key>
  <dict/>
  <key>UISupportedInterfaceOrientations</key>
  <array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
  </array>
</dict>
</plist>
`)

      // ios/Sources/AppDelegate.swift
      await writeFile(join(iosSrcDir, 'AppDelegate.swift'), `import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }

    // MARK: UISceneSession Lifecycle
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }
}
`)

      // ios/Sources/SceneDelegate.swift
      await writeFile(join(iosSrcDir, 'SceneDelegate.swift'), `import UIKit
import VueNativeCore

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = AppViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
}

class AppViewController: VueNativeViewController {
    override var bundleName: String { "vue-native-bundle" }

    #if DEBUG
    override var devServerURL: URL? { URL(string: "ws://localhost:8174") }
    #endif
}
`)

      // ── Android native project ─────────────────────────────
      const androidDir = join(dir, 'android')
      const androidAppDir = join(androidDir, 'app')
      const androidPkg = `com.vuenative.${name.replace(/[^a-zA-Z0-9]/g, '').toLowerCase()}`
      const androidPkgPath = androidPkg.replace(/\./g, '/')
      const androidSrcDir = join(androidAppDir, 'src', 'main')
      const androidKotlinDir = join(androidSrcDir, 'kotlin', androidPkgPath)
      await mkdir(androidKotlinDir, { recursive: true })

      // android/build.gradle.kts
      await writeFile(join(androidDir, 'build.gradle.kts'), `// Top-level build file
plugins {
    id("com.android.application") version "8.2.2" apply false
    id("com.android.library") version "8.2.2" apply false
    id("org.jetbrains.kotlin.android") version "1.9.22" apply false
}
`)

      // android/settings.gradle.kts
      await writeFile(join(androidDir, 'settings.gradle.kts'), `pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}

rootProject.name = "${name}"
include(":app")
include(":VueNativeCore")
project(":VueNativeCore").projectDir = file("../native/android/VueNativeCore")
`)

      // android/app/build.gradle.kts
      await writeFile(join(androidAppDir, 'build.gradle.kts'), `plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "${androidPkg}"
    compileSdk = 34

    defaultConfig {
        applicationId = "${androidPkg}"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation(project(":VueNativeCore"))
}
`)

      // android/app/src/main/AndroidManifest.xml
      await writeFile(join(androidSrcDir, 'AndroidManifest.xml'), `<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />

    <application
        android:allowBackup="true"
        android:label="${name}"
        android:supportsRtl="true"
        android:theme="@style/Theme.AppCompat.Light.NoActionBar"
        android:usesCleartextTraffic="true">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
`)

      // android/app/src/main/kotlin/.../MainActivity.kt
      await writeFile(join(androidKotlinDir, 'MainActivity.kt'), `package ${androidPkg}

import com.vuenative.core.VueNativeActivity

class MainActivity : VueNativeActivity() {
    override fun getBundleAssetPath(): String {
        return "vue-native-bundle.js"
    }

    override fun getDevServerUrl(): String? {
        return "ws://10.0.2.2:8174"
    }
}
`)

      // android/gradle.properties
      await writeFile(join(androidDir, 'gradle.properties'), `# Project-wide Gradle settings
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
`)

      console.log(pc.green('✓ Project created successfully!\n'))
      console.log(pc.white('Next steps:\n'))
      console.log(pc.white(`  cd ${name}`))
      console.log(pc.white('  bun install'))
      console.log(pc.white('  vue-native dev\n'))
      console.log(pc.white('To run on iOS:'))
      console.log(pc.white('  vue-native run ios\n'))
      console.log(pc.white('To run on Android:'))
      console.log(pc.white('  vue-native run android\n'))
    } catch (err) {
      console.error(pc.red(`Error creating project: ${(err as Error).message}`))
      process.exit(1)
    }
  })
