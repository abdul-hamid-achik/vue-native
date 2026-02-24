import { Command } from 'commander'
import { cp, mkdir, writeFile } from 'node:fs/promises'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { existsSync } from 'node:fs'
import pc from 'picocolors'

const VERSION = '0.4.6'

type Template = 'blank' | 'tabs' | 'drawer'

export const createCommand = new Command('create')
  .description('Create a new Vue Native project')
  .argument('<name>', 'project name')
  .option('-t, --template <template>', 'project template (blank, tabs, drawer)', 'blank')
  .action(async (name: string, options: { template: string }) => {
    const template = options.template as Template
    if (!['blank', 'tabs', 'drawer'].includes(template)) {
      console.error(pc.red(`Invalid template "${template}". Choose: blank, tabs, drawer`))
      process.exit(1)
    }

    const dir = join(process.cwd(), name)
    console.log(pc.cyan(`\nCreating Vue Native project: ${pc.bold(name)} (template: ${template})\n`))

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
          '@thelacanians/vue-native-runtime': '^0.4.0',
          '@thelacanians/vue-native-navigation': '^0.4.0',
          'vue': '^3.5.0',
        },
        devDependencies: {
          '@thelacanians/vue-native-vite-plugin': '^0.4.0',
          '@vitejs/plugin-vue': '^5.0.0',
          'vite': '^6.1.0',
          'typescript': '^5.7.0',
        },
      }, null, 2))

      // vite.config.ts
      await writeFile(join(dir, 'vite.config.ts'), `import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueNative from '@thelacanians/vue-native-vite-plugin'

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
          paths: {
            vue: ['./node_modules/@thelacanians/vue-native-runtime/dist/index.d.ts'],
          },
        },
        include: ['app/**/*', 'env.d.ts'],
      }, null, 2))

      // Generate template-specific files
      await generateTemplateFiles(dir, name, template)

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
    url: https://github.com/abdul-hamid-achik/vue-native
    from: "${VERSION}"

targets:
  ${xcodeProjectName}:
    type: application
    platform: iOS
    sources:
      - Sources
    dependencies:
      - package: VueNativeCore
        product: VueNativeCore
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
  <!-- Uncomment the privacy descriptions for features your app uses -->
  <!-- <key>NSCameraUsageDescription</key><string>This app needs camera access</string> -->
  <!-- <key>NSMicrophoneUsageDescription</key><string>This app needs microphone access</string> -->
  <!-- <key>NSLocationWhenInUseUsageDescription</key><string>This app needs your location</string> -->
  <!-- <key>NSPhotoLibraryUsageDescription</key><string>This app needs photo library access</string> -->
  <!-- <key>NSContactsUsageDescription</key><string>This app needs contacts access</string> -->
  <!-- <key>NSCalendarsUsageDescription</key><string>This app needs calendar access</string> -->
  <!-- <key>NSBluetoothAlwaysUsageDescription</key><string>This app needs Bluetooth access</string> -->
  <!-- <key>NSFaceIDUsageDescription</key><string>This app uses Face ID for authentication</string> -->
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
      const androidResValuesDir = join(androidSrcDir, 'res', 'values')
      const androidResXmlDir = join(androidSrcDir, 'res', 'xml')
      const androidDebugResXmlDir = join(androidAppDir, 'src', 'debug', 'res', 'xml')
      const androidGradleWrapperDir = join(androidDir, 'gradle', 'wrapper')
      await mkdir(androidKotlinDir, { recursive: true })
      await mkdir(androidResValuesDir, { recursive: true })
      await mkdir(androidResXmlDir, { recursive: true })
      await mkdir(androidDebugResXmlDir, { recursive: true })
      await mkdir(androidGradleWrapperDir, { recursive: true })

      // android/build.gradle.kts (top-level)
      await writeFile(join(androidDir, 'build.gradle.kts'), `// Top-level build file
plugins {
    id("com.android.application") version "8.7.3" apply false
    id("com.android.library") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
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
        maven {
            url = uri("https://maven.pkg.github.com/abdul-hamid-achik/vue-native")
            credentials {
                username = providers.gradleProperty("gpr.user").orNull ?: System.getenv("GITHUB_ACTOR") ?: ""
                password = providers.gradleProperty("gpr.key").orNull ?: System.getenv("GITHUB_TOKEN") ?: ""
            }
        }
    }
}

rootProject.name = "${name}"
include(":app")
`)

      // android/app/build.gradle.kts
      await writeFile(join(androidAppDir, 'build.gradle.kts'), `plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "${androidPkg}"
    compileSdk = 35

    defaultConfig {
        applicationId = "${androidPkg}"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    buildFeatures {
        buildConfig = true
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
    implementation("com.vuenative:core:${VERSION}")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
    implementation("androidx.core:core-ktx:1.15.0")
}
`)

      // android/app/proguard-rules.pro
      await writeFile(join(androidAppDir, 'proguard-rules.pro'), `# Vue Native
-keep class com.vuenative.** { *; }

# J2V8
-keep class com.eclipsesource.v8.** { *; }
`)

      // android/app/src/main/AndroidManifest.xml
      await writeFile(join(androidSrcDir, 'AndroidManifest.xml'), `<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />

    <application
        android:allowBackup="true"
        android:label="@string/app_name"
        android:supportsRtl="true"
        android:theme="@style/Theme.VueNative"
        android:networkSecurityConfig="@xml/network_security_config">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:configChanges="orientation|screenSize|screenLayout|keyboardHidden|keyboard|locale|layoutDirection|fontScale|uiMode|density"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
`)

      // android/app/src/main/res/values/strings.xml
      await writeFile(join(androidResValuesDir, 'strings.xml'), `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">${name}</string>
</resources>
`)

      // android/app/src/main/res/values/themes.xml
      await writeFile(join(androidResValuesDir, 'themes.xml'), `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.VueNative" parent="Theme.MaterialComponents.Light.NoActionBar">
        <item name="colorPrimary">#4F46E5</item>
        <item name="colorPrimaryVariant">#3730A3</item>
        <item name="colorOnPrimary">#FFFFFF</item>
        <item name="colorSecondary">#10B981</item>
        <item name="colorSecondaryVariant">#059669</item>
        <item name="colorOnSecondary">#FFFFFF</item>
        <item name="android:statusBarColor">@android:color/transparent</item>
    </style>
</resources>
`)

      // android/app/src/main/res/xml/network_security_config.xml (release: no cleartext)
      await writeFile(join(androidResXmlDir, 'network_security_config.xml'), `<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false" />
</network-security-config>
`)

      // android/app/src/debug/res/xml/network_security_config.xml (debug: allow dev server)
      await writeFile(join(androidDebugResXmlDir, 'network_security_config.xml'), `<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">localhost</domain>
        <domain includeSubdomains="true">127.0.0.1</domain>
        <domain includeSubdomains="true">10.0.2.2</domain>
    </domain-config>
</network-security-config>
`)

      // android/app/src/main/kotlin/.../MainActivity.kt
      await writeFile(join(androidKotlinDir, 'MainActivity.kt'), `package ${androidPkg}

import com.vuenative.core.VueNativeActivity

class MainActivity : VueNativeActivity() {
    override fun getBundleAssetPath(): String {
        return "vue-native-bundle.js"
    }

    override fun getDevServerUrl(): String? {
        return if (BuildConfig.DEBUG) "ws://10.0.2.2:8174" else null
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

      // android/gradle/wrapper/gradle-wrapper.properties
      await writeFile(join(androidGradleWrapperDir, 'gradle-wrapper.properties'), `distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\\://services.gradle.org/distributions/gradle-8.11.1-bin.zip
networkTimeout=10000
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
`)

      // vue-native.config.ts
      await writeFile(join(dir, 'vue-native.config.ts'), `import { defineConfig } from '@thelacanians/vue-native-cli'

export default defineConfig({
  name: '${name}',
  bundleId: '${bundleId}',
  version: '1.0.0',
  ios: {
    deploymentTarget: '16.0',
  },
  android: {
    minSdk: 24,
    targetSdk: 35,
  },
})
`)

      // env.d.ts
      await writeFile(join(dir, 'env.d.ts'), `/// <reference types="vite/client" />
declare module '*.vue' {
  import type { DefineComponent } from '@thelacanians/vue-native-runtime'
  const component: DefineComponent<{}, {}, any>
  export default component
}
declare const __DEV__: boolean
`)

      // .gitignore
      await writeFile(join(dir, '.gitignore'), `node_modules/
dist/
*.xcuserstate
*.xcuserdatad/
DerivedData/
.build/
build/
.gradle/
local.properties
*.apk
*.aab
.DS_Store

# Environment & secrets
.env
.env.local
.env.*.local
*.pem
*.key
*.keystore
*.jks
`)

      // ── Copy bundled native/ as fallback ───────────────────
      // When the CLI is installed from npm, native/ is bundled alongside dist/.
      // This lets projects work immediately without waiting for SPM/Maven resolution.
      const cliDir = dirname(dirname(fileURLToPath(import.meta.url)))
      const bundledNative = join(cliDir, 'native')
      if (existsSync(bundledNative)) {
        const nativeDir = join(dir, 'native')
        await cp(bundledNative, nativeDir, { recursive: true })
        console.log(pc.dim('  Bundled native/ copied as fallback.\n'))
      }

      console.log(pc.green('  Project created successfully!\n'))
      console.log(pc.white('  Next steps:\n'))
      console.log(pc.white(`    cd ${name}`))
      console.log(pc.white('    bun install'))
      console.log(pc.white('    vue-native dev\n'))
      console.log(pc.white('  To run on iOS:'))
      console.log(pc.white('    vue-native run ios\n'))
      console.log(pc.white('  To run on Android:'))
      console.log(pc.dim('    Open android/ in Android Studio, or run:'))
      console.log(pc.dim('    cd android && gradle wrapper && cd ..'))
      console.log(pc.white('    vue-native run android\n'))
    } catch (err) {
      console.error(pc.red(`Error creating project: ${(err as Error).message}`))
      process.exit(1)
    }
  })

// ---------------------------------------------------------------------------
// Template generators
// ---------------------------------------------------------------------------

async function generateTemplateFiles(dir: string, name: string, template: Template) {
  const pagesDir = join(dir, 'app', 'pages')

  if (template === 'blank') {
    await generateBlankTemplate(dir, pagesDir)
  } else if (template === 'tabs') {
    await generateTabsTemplate(dir, pagesDir)
  } else if (template === 'drawer') {
    await generateDrawerTemplate(dir, pagesDir)
  }
}

async function generateBlankTemplate(dir: string, pagesDir: string) {
  // app/main.ts
  await writeFile(join(dir, 'app', 'main.ts'), `import { createApp } from '@thelacanians/vue-native-runtime'
import { createRouter } from '@thelacanians/vue-native-navigation'
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
import { RouterView } from '@thelacanians/vue-native-navigation'
</script>
`)

  // app/pages/Home.vue
  await writeFile(join(pagesDir, 'Home.vue'), `<script setup lang="ts">
import { ref } from 'vue'
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

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

<template>
  <VView :style="styles.container">
    <VText :style="styles.title">Hello, Vue Native!</VText>
    <VText :style="styles.subtitle">Edit app/pages/Home.vue to get started.</VText>
    <VButton :style="styles.button" :onPress="() => count++">
      <VText :style="styles.buttonText">Count: {{ count }}</VText>
    </VButton>
  </VView>
</template>
`)
}

async function generateTabsTemplate(dir: string, pagesDir: string) {
  // app/main.ts
  await writeFile(join(dir, 'app', 'main.ts'), `import { createApp } from '@thelacanians/vue-native-runtime'
import App from './App.vue'

const app = createApp(App)
app.start()
`)

  // app/App.vue — uses createTabNavigator
  await writeFile(join(dir, 'app', 'App.vue'), `<script setup lang="ts">
import { createTabNavigator } from '@thelacanians/vue-native-navigation'
import Home from './pages/Home.vue'
import Settings from './pages/Settings.vue'

const { TabNavigator } = createTabNavigator()
</script>

<template>
  <VSafeArea :style="{ flex: 1, backgroundColor: '#ffffff' }">
    <TabNavigator
      :screens="[
        { name: 'home', label: 'Home', icon: 'H', component: Home },
        { name: 'settings', label: 'Settings', icon: 'S', component: Settings },
      ]"
    />
  </VSafeArea>
</template>
`)

  // app/pages/Home.vue
  await writeFile(join(pagesDir, 'Home.vue'), `<script setup lang="ts">
import { ref } from 'vue'
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

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
    marginBottom: 16,
  },
  button: {
    backgroundColor: '#4f46e5',
    paddingHorizontal: 32,
    paddingVertical: 14,
    borderRadius: 12,
    marginTop: 16,
  },
  buttonText: {
    color: '#ffffff',
    fontSize: 18,
    fontWeight: '600',
  },
})
</script>

<template>
  <VView :style="styles.container">
    <VText :style="styles.title">Home</VText>
    <VText>Count: {{ count }}</VText>
    <VButton :style="styles.button" :onPress="() => count++">
      <VText :style="styles.buttonText">Increment</VText>
    </VButton>
  </VView>
</template>
`)

  // app/pages/Settings.vue
  await writeFile(join(pagesDir, 'Settings.vue'), `<script setup lang="ts">
import { ref } from 'vue'
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const darkMode = ref(false)

const styles = createStyleSheet({
  container: {
    flex: 1,
    padding: 24,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1a1a1a',
    marginBottom: 24,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  label: {
    fontSize: 16,
    color: '#333',
  },
})
</script>

<template>
  <VView :style="styles.container">
    <VText :style="styles.title">Settings</VText>
    <VView :style="styles.row">
      <VText :style="styles.label">Dark Mode</VText>
      <VSwitch v-model="darkMode" />
    </VView>
  </VView>
</template>
`)
}

async function generateDrawerTemplate(dir: string, pagesDir: string) {
  // app/main.ts
  await writeFile(join(dir, 'app', 'main.ts'), `import { createApp } from '@thelacanians/vue-native-runtime'
import App from './App.vue'

const app = createApp(App)
app.start()
`)

  // app/App.vue — uses createDrawerNavigator
  await writeFile(join(dir, 'app', 'App.vue'), `<script setup lang="ts">
import { createDrawerNavigator } from '@thelacanians/vue-native-navigation'
import Home from './pages/Home.vue'
import About from './pages/About.vue'

const { DrawerNavigator } = createDrawerNavigator()
</script>

<template>
  <VSafeArea :style="{ flex: 1, backgroundColor: '#ffffff' }">
    <DrawerNavigator
      :screens="[
        { name: 'home', label: 'Home', icon: 'H', component: Home },
        { name: 'about', label: 'About', icon: 'A', component: About },
      ]"
    />
  </VSafeArea>
</template>
`)

  // app/pages/Home.vue
  await writeFile(join(pagesDir, 'Home.vue'), `<script setup lang="ts">
import { createStyleSheet } from '@thelacanians/vue-native-runtime'
import { useDrawer } from '@thelacanians/vue-native-navigation'

const { toggleDrawer } = useDrawer()

const styles = createStyleSheet({
  container: {
    flex: 1,
    padding: 24,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 24,
  },
  menuButton: {
    backgroundColor: '#f0f0f0',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 8,
    marginRight: 16,
  },
  menuText: {
    fontSize: 18,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1a1a1a',
  },
  body: {
    fontSize: 16,
    color: '#666',
    lineHeight: 24,
  },
})
</script>

<template>
  <VView :style="styles.container">
    <VView :style="styles.header">
      <VButton :style="styles.menuButton" :onPress="toggleDrawer">
        <VText :style="styles.menuText">Menu</VText>
      </VButton>
      <VText :style="styles.title">Home</VText>
    </VView>
    <VText :style="styles.body">
      Swipe from the left or tap Menu to open the drawer.
    </VText>
  </VView>
</template>
`)

  // app/pages/About.vue
  await writeFile(join(pagesDir, 'About.vue'), `<script setup lang="ts">
import { createStyleSheet } from '@thelacanians/vue-native-runtime'
import { useDrawer } from '@thelacanians/vue-native-navigation'

const { toggleDrawer } = useDrawer()

const styles = createStyleSheet({
  container: {
    flex: 1,
    padding: 24,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 24,
  },
  menuButton: {
    backgroundColor: '#f0f0f0',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 8,
    marginRight: 16,
  },
  menuText: {
    fontSize: 18,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1a1a1a',
  },
  body: {
    fontSize: 16,
    color: '#666',
    lineHeight: 24,
  },
})
</script>

<template>
  <VView :style="styles.container">
    <VView :style="styles.header">
      <VButton :style="styles.menuButton" :onPress="toggleDrawer">
        <VText :style="styles.menuText">Menu</VText>
      </VButton>
      <VText :style="styles.title">About</VText>
    </VView>
    <VText :style="styles.body">
      Built with Vue Native.
    </VText>
  </VView>
</template>
`)
}
