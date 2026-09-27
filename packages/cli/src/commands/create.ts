import { Command } from 'commander'
import { chmod, cp, mkdir, writeFile } from 'node:fs/promises'
import { basename, join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { existsSync, readFileSync } from 'node:fs'
import pc from 'picocolors'
import cliPackage from '../../package.json'
import { ConfigError } from '../config.js'
import { canPrompt, p, unwrap } from '../ui.js'

const DEFAULT_VUE_VERSION = cliPackage.vueNative.vueVersion

/**
 * Minimum macOS version for the scaffolded host.
 *
 * One constant because four places have to agree: macos/project.yml's
 * `options.deploymentTarget.macOS`, the target's `MACOSX_DEPLOYMENT_TARGET`
 * (which Info.plist's `LSMinimumSystemVersion` expands from), the
 * `macos.deploymentTarget` written into vue-native.config.ts, and the default
 * config.ts resolves when that key is absent. VueNativeMacOS itself declares
 * `platforms: [.macOS(.v15)]`.
 */
const MACOS_DEPLOYMENT_TARGET = '15.0'

const VUE_COHORT_PACKAGES = [
  'vue',
  '@vue/compiler-core',
  '@vue/compiler-dom',
  '@vue/compiler-sfc',
  '@vue/compiler-ssr',
  '@vue/reactivity',
  '@vue/runtime-core',
  '@vue/runtime-dom',
  '@vue/server-renderer',
  '@vue/shared',
  ...(Number(DEFAULT_VUE_VERSION.split('.')[1]) >= 6
    ? ['@vue/compiler-vapor', '@vue/runtime-vapor']
    : []),
]

function getCliPackageDir(): string {
  const moduleDir = dirname(fileURLToPath(import.meta.url))
  const parentDir = dirname(moduleDir)

  // Source execution: packages/cli/src/commands/create.ts
  if (basename(moduleDir) === 'commands' && basename(parentDir) === 'src') {
    return dirname(parentDir)
  }

  // Published build: packages/cli/dist/cli.js
  return parentDir
}

function getTemplateVersions() {
  // Derive versions from the CLI's own package.json. The CLI is in the
  // changesets `fixed` group with runtime/navigation/vite-plugin, so its
  // version is also the iOS SPM tag.
  try {
    const cliDir = getCliPackageDir()
    const pkg = JSON.parse(readFileSync(join(cliDir, 'package.json'), 'utf8'))
    const viteDevDep = pkg.devDependencies?.vite
    const viteVuePluginDevDep = pkg.devDependencies?.['@vitejs/plugin-vue']
    const vueVersion = pkg.vueNative?.vueVersion
    return {
      JS_PACKAGE_VERSION: `^${pkg.version}`,
      VUE_VERSION: vueVersion ?? DEFAULT_VUE_VERSION,
      VITE_PLUGIN_VUE_VERSION: viteVuePluginDevDep ?? '^6.0.5',
      VITE_VERSION: viteDevDep ?? '^8.0.0',
    }
  } catch {
    return {
      JS_PACKAGE_VERSION: '^0.0.0',
      VUE_VERSION: DEFAULT_VUE_VERSION,
      VITE_PLUGIN_VUE_VERSION: '^6.0.5',
      VITE_VERSION: '^8.0.0',
    }
  }
}

const {
  JS_PACKAGE_VERSION,
  VITE_PLUGIN_VUE_VERSION,
  VITE_VERSION,
  VUE_VERSION,
} = getTemplateVersions()

const VALID_NAME = /^[a-zA-Z][a-zA-Z0-9_-]*$/

type Template = 'blank' | 'tabs' | 'drawer'

const TEMPLATE_CHOICES: Template[] = ['blank', 'tabs', 'drawer']

async function resolveProjectName(provided: string | undefined): Promise<string> {
  if (provided) return provided
  if (!canPrompt()) {
    throw new ConfigError(
      'Project name is required. Pass it as an argument: vue-native create <name>',
    )
  }
  return unwrap(await p.text({
    message: 'What is your project named?',
    placeholder: 'my-app',
    validate: (value) => {
      if (!value) return 'Project name is required.'
      if (!VALID_NAME.test(value)) {
        return 'Must start with a letter and contain only letters, numbers, hyphens, or underscores.'
      }
      if (existsSync(join(process.cwd(), value))) {
        return `"${value}" already exists. Choose a different name.`
      }
      return undefined
    },
  }))
}

async function resolveTemplate(provided: string | undefined): Promise<Template> {
  if (provided !== undefined) {
    if (!TEMPLATE_CHOICES.includes(provided as Template)) {
      throw new ConfigError(
        `Invalid template "${provided}". Choose: blank, tabs, drawer`,
      )
    }
    return provided as Template
  }
  if (!canPrompt()) return 'blank'
  return unwrap(await p.select({
    message: 'Which template would you like to use?',
    options: [
      { value: 'blank', label: 'blank', hint: 'single screen with a counter' },
      { value: 'tabs', label: 'tabs', hint: 'bottom tab navigation' },
      { value: 'drawer', label: 'drawer', hint: 'side drawer navigation' },
    ],
  })) as Template
}

export const createCommand = new Command('create')
  .description('Create a new Vue Native project')
  .argument('[name]', 'project name')
  .option('-t, --template <template>', 'project template (blank, tabs, drawer)')
  .action(async (nameArg: string | undefined, options: { template?: string }) => {
    p.intro(pc.cyan('Vue Native'))

    const name = await resolveProjectName(nameArg)
    const template = await resolveTemplate(options.template)

    if (!VALID_NAME.test(name)) {
      throw new ConfigError(
        `Project name "${name}" must start with a letter and contain only letters, numbers, hyphens, or underscores.`,
      )
    }

    const dir = join(process.cwd(), name)
    if (existsSync(dir)) {
      throw new ConfigError(
        `Cannot create "${name}": ${dir} already exists. Choose a new name or remove the existing directory.`,
      )
    }
    p.log.info(`Creating ${pc.bold(name)} (template: ${template})`)

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
          '@thelacanians/vue-native-runtime': JS_PACKAGE_VERSION,
          '@thelacanians/vue-native-navigation': JS_PACKAGE_VERSION,
          'vue': VUE_VERSION,
        },
        devDependencies: {
          '@thelacanians/vue-native-cli': JS_PACKAGE_VERSION,
          '@thelacanians/vue-native-vite-plugin': JS_PACKAGE_VERSION,
          '@vitejs/plugin-vue': VITE_PLUGIN_VUE_VERSION,
          'esbuild': '^0.27.0',
          'vite': VITE_VERSION,
          'typescript': '^5.7.0',
        },
        overrides: Object.fromEntries(
          VUE_COHORT_PACKAGES.map(packageName => [packageName, VUE_VERSION]),
        ),
      }, null, 2))

      // vite.config.ts
      await writeFile(join(dir, 'vite.config.ts'), `import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueNative from '@thelacanians/vue-native-vite-plugin'

export default defineConfig({
  plugins: [vue(), vueNative({
    nativeOutputDirs: {
      typescript: 'app/generated',
    },
  })],
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
          skipLibCheck: true,
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
    path: ../native/ios/VueNativeCore

targets:
  ${xcodeProjectName}:
    type: application
    platform: iOS
    sources:
      - Sources
      - path: ../dist/vue-native-bundle.js
        buildPhase: resources
        optional: true
    dependencies:
      - package: VueNativeCore
        product: VueNativeCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: ${bundleId}
        INFOPLIST_FILE: Sources/Info.plist
        SWIFT_VERSION: "5.9"
        GENERATE_INFOPLIST_FILE: false
        # Expanded into Info.plist's VueNativeDevServerURL. Overridable per
        # build: \`xcodebuild DEV_SERVER_URL=ws://localhost:9000 ...\`, which is
        # what \`vue-native run ios --port 9000\` passes.
        DEV_SERVER_URL: "ws://localhost:8174"
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
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
  </dict>
  <!--
    iOS privacy usage descriptions.
    These are NOT optional comments: iOS terminates the process the moment a
    gated framework (camera, microphone, location, photos, contacts, calendars,
    Bluetooth, Face ID) is touched without its usage string, so a commented-out
    key turns the first useCamera() call in a fresh app into a hard crash with
    no diagnostic. The strings are only *shown* when the corresponding API is
    actually called, so an app that never uses one never prompts for it.
    Before App Store submission, delete the entries your app does not use —
    declaring a sensitive purpose you never exercise is itself a rejection
    reason.
  -->
  <key>NSCameraUsageDescription</key><string>This app uses the camera when you choose to take a photo or scan a code.</string>
  <key>NSMicrophoneUsageDescription</key><string>This app records audio when you choose to record.</string>
  <key>NSLocationWhenInUseUsageDescription</key><string>This app uses your location while in use when you choose to share it.</string>
  <key>NSPhotoLibraryUsageDescription</key><string>This app reads from your photo library when you choose a photo.</string>
  <key>NSContactsUsageDescription</key><string>This app reads contacts when you choose to look one up.</string>
  <key>NSCalendarsUsageDescription</key><string>This app reads and writes calendar events when you choose to.</string>
  <key>NSBluetoothAlwaysUsageDescription</key><string>This app connects to Bluetooth devices when you choose to pair one.</string>
  <key>NSFaceIDUsageDescription</key><string>This app uses Face ID or Touch ID when you choose to authenticate.</string>
  <!--
    Dev-server URL for hot reload, expanded from the DEV_SERVER_URL build
    setting at build time so \`vue-native run ios --port N\` can redirect the
    host without editing any project file. Only read in DEBUG builds.
  -->
  <key>VueNativeDevServerURL</key>
  <string>$(DEV_SERVER_URL)</string>
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
    /// Injected at build time from the DEV_SERVER_URL build setting, which
    /// \`vue-native run ios --port\` overrides on the xcodebuild command line.
    /// The Info.plist value is \`$(DEV_SERVER_URL)\`, so it expands to whatever
    /// the build was given; the literal fallback keeps hand-written hosts and
    /// projects scaffolded before this setting existed working.
    override var devServerURL: URL? {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "VueNativeDevServerURL") as? String,
           !configured.isEmpty,
           let url = URL(string: configured) {
            return url
        }
        return URL(string: "ws://localhost:8174")
    }
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
    id("org.jlleitschuh.gradle.ktlint") version "12.1.0" apply false
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
    compileSdk = 35

    defaultConfig {
        applicationId = "${androidPkg}"
        minSdk = 21
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
        // Hot-reload endpoint for debug builds. Overridable per invocation:
        // \`./gradlew -PdevServerUrl=ws://10.0.2.2:9000 ...\`, which is what
        // \`vue-native run android --port 9000\` passes. 10.0.2.2 is the
        // emulator's alias for the host machine's loopback.
        buildConfigField(
            "String",
            "DEV_SERVER_URL",
            "\\"" + (project.findProperty("devServerUrl") as String? ?: "ws://10.0.2.2:8174") + "\\"",
        )
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
    implementation(project(":VueNativeCore"))
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
        return if (BuildConfig.DEBUG) BuildConfig.DEV_SERVER_URL else null
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
      // AGP 8.7.x (declared in the top-level build.gradle.kts above) requires
      // Gradle 8.9 or newer; 8.6 made every scaffolded Android app fail its first
      // build with "Minimum supported Gradle version is 8.9".
      await writeFile(join(androidGradleWrapperDir, 'gradle-wrapper.properties'), `distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\\://services.gradle.org/distributions/gradle-8.11.1-bin.zip
networkTimeout=10000
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
`)

      // Ship a self-contained Android project. GitHub's Maven registry requires
      // authentication even for public packages, so fresh apps consume the
      // bundled VueNativeCore project and wrapper without asking users for a PAT
      // or a globally-installed Gradle executable.
      const bundledNative = join(getCliPackageDir(), 'native')
      const bundledAndroid = join(bundledNative, 'android')
      try {
        // Keep the canonical native/ layout so native-block code generation
        // writes into the exact sources consumed by the local Android module.
        await cp(bundledNative, join(dir, 'native'), { recursive: true })
        await cp(join(bundledAndroid, 'gradlew'), join(androidDir, 'gradlew'))
        await cp(join(bundledAndroid, 'gradlew.bat'), join(androidDir, 'gradlew.bat'))
        await cp(
          join(bundledAndroid, 'gradle', 'wrapper', 'gradle-wrapper.jar'),
          join(androidGradleWrapperDir, 'gradle-wrapper.jar'),
        )
        await chmod(join(androidDir, 'gradlew'), 0o755)
      } catch (error) {
        throw new ConfigError(
          `Bundled Android runtime files are missing or unreadable: ${(error as Error).message}`,
        )
      }
      p.log.step('Bundled native runtimes copied for local builds.')

      // ── Vendored native runtime version stamp ──────────────
      // The copy above puts the entire framework source tree (~424 files) into
      // the new project, and .gitignore deliberately does NOT exclude native/ —
      // the tree is committed. Nothing recorded which CLI wrote it, so a stale
      // copy was indistinguishable from a locally-edited one and there was no
      // basis for an `upgrade` command. This stamp is that record.
      await writeFile(
        join(dir, 'native', '.vue-native-version'),
        `${JSON.stringify({
          schema: 1,
          cliVersion: cliPackage.version,
          // runtime/navigation/vite-plugin are in the same changesets `fixed`
          // group as the CLI, so the CLI version *is* the framework version.
          frameworkVersion: cliPackage.version,
          jsDependencyRange: JS_PACKAGE_VERSION,
          vendoredFrom: '@thelacanians/vue-native-cli/native',
          generatedAt: new Date().toISOString(),
        }, null, 2)}\n`,
      )

      // ── macOS native project ───────────────────────────────
      //
      // XcodeGen, not a bare SPM executable target. Two reasons, both hard:
      //
      //  1. `swift build` produces a Mach-O binary in .build/debug/, not a
      //     .app bundle. VueNativeWindowController loads the JS bundle through
      //     `Bundle.main.url(forResource:withExtension:)` (JSRuntime.swift), so
      //     a host without a real bundle finds no bundle and boots to the
      //     DEBUG error overlay. An .app is also what gives us Info.plist,
      //     Contents/Resources/vue-native-bundle.js, an activation policy and a
      //     Dock item — and what `vue-native run macos` launches with `open`.
      //  2. run.ts/build.ts already resolve `.xcodeproj`/`.xcworkspace` in
      //     macos/ and locate the product with findAppleAppBundle(). XcodeGen
      //     makes macOS reuse the exact iOS path (project.yml committed,
      //     generated project gitignored, ensureXcodeProject shared).
      //
      // The VueNativeMacOS package declares `VueNativeShared` as a *local*
      // `path: ../../shared/VueNativeShared` dependency, so it cannot be
      // resolved from a git URL. That is fine here: the copy above preserves
      // the canonical `native/{macos,shared}` layout, so the relative path
      // still resolves inside the generated project and we point XcodeGen at
      // the vendored package rather than a remote one.
      const macosDir = join(dir, 'macos')
      const macosSrcDir = join(macosDir, 'Sources')
      await mkdir(macosSrcDir, { recursive: true })
      const copyrightYear = new Date().getFullYear()

      // macos/project.yml (XcodeGen spec)
      await writeFile(join(macosDir, 'project.yml'), `name: ${xcodeProjectName}
options:
  bundleIdPrefix: com.vuenative
  deploymentTarget:
    macOS: "${MACOS_DEPLOYMENT_TARGET}"
  xcodeVersion: "15.0"

packages:
  # Vendored copy, not a git URL: VueNativeMacOS depends on VueNativeShared by
  # local path (../../shared/VueNativeShared), which only resolves inside the
  # native/ tree that create copies into this project.
  VueNativeMacOS:
    path: ../native/macos/VueNativeMacOS

targets:
  ${xcodeProjectName}:
    type: application
    platform: macOS
    sources:
      # Info.plist and App.entitlements are consumed through build settings
      # (INFOPLIST_FILE / CODE_SIGN_ENTITLEMENTS). Excluding them here keeps
      # XcodeGen from also adding them to Copy Bundle Resources, which would
      # make two build steps produce the same file.
      - path: Sources
        excludes:
          - Info.plist
          - App.entitlements
      # The Vite output, copied into Contents/Resources so JSRuntime's
      # Bundle.main lookup for "vue-native-bundle.js" succeeds.
      - path: ../dist/vue-native-bundle.js
        buildPhase: resources
        optional: true
    # An explicit scheme block makes XcodeGen write a shared scheme into the
    # generated .xcodeproj. Without it the only scheme is the one Xcode
    # autocreates into xcuserdata on first use, so \`xcodebuild -scheme ${xcodeProjectName}\`
    # depends on state that a fresh clone and CI do not have.
    scheme: {}
    dependencies:
      - package: VueNativeMacOS
        product: VueNativeMacOS
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: ${bundleId}
        INFOPLIST_FILE: Sources/Info.plist
        CODE_SIGN_ENTITLEMENTS: Sources/App.entitlements
        GENERATE_INFOPLIST_FILE: false
        MACOSX_DEPLOYMENT_TARGET: "${MACOS_DEPLOYMENT_TARGET}"
        # Expanded into Info.plist's VueNativeDevServerURL. Overridable per
        # build: \`xcodebuild DEV_SERVER_URL=ws://localhost:9000 ...\`, which is
        # what \`vue-native run macos --port 9000\` passes.
        DEV_SERVER_URL: "ws://localhost:8174"
        SWIFT_VERSION: "5.9"
        # Xcode's macOS app template sets this and XcodeGen does not. Today the
        # SPM products link statically (a verified build emits no
        # Contents/Frameworks), so it is inert — but it is the rpath a
        # dynamically-linked dependency would need, and omitting it is how a
        # host that later adds one ends up crashing in dyld at launch.
        LD_RUNPATH_SEARCH_PATHS: "$(inherited) @executable_path/../Frameworks"
        COMBINE_HIDPI_IMAGES: YES
        # Ad-hoc signing so \`run macos\`/\`build macos\` work with no Apple
        # Developer team configured. Change CODE_SIGN_STYLE to Automatic and
        # set DEVELOPMENT_TEAM before distributing outside this machine.
        CODE_SIGN_STYLE: Manual
        CODE_SIGN_IDENTITY: "-"
        DEVELOPMENT_TEAM: ""
        ENABLE_HARDENED_RUNTIME: NO
`)

      // macos/Sources/Info.plist
      //
      // Every key below is live, not commented out. The iOS scaffold ships its
      // usage descriptions inside XML comments, which means the first app that
      // calls useCamera()/useGeolocation() crashes in TCC instead of prompting
      // — that defect is deliberately not replicated here. Only the three
      // descriptions the vendored macOS framework can actually reach are
      // included: CameraModule (AVCaptureDevice), the shared AudioModule's
      // record path (AVAudioRecorder) and the shared GeolocationModule
      // (CLLocationManager). Contacts/Calendar/Bluetooth/Photos have no macOS
      // code path in the framework, so shipping strings for them would be
      // noise. LocalAuthentication (BiometryModule) and UNUserNotificationCenter
      // (NotificationsModule) need no Info.plist string on macOS.
      await writeFile(join(macosSrcDir, 'Info.plist'), `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${name}</string>
  <key>CFBundleExecutable</key>
  <string>$(EXECUTABLE_NAME)</string>
  <key>CFBundleIconFile</key>
  <string></string>
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
  <key>LSMinimumSystemVersion</key>
  <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © ${copyrightYear} ${name}. All rights reserved.</string>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
  </dict>
  <!--
    Dev-server URL for hot reload, expanded from the DEV_SERVER_URL build
    setting at build time so \`vue-native run macos --port N\` can redirect the
    host without editing any project file. Only read in DEBUG builds.
  -->
  <key>VueNativeDevServerURL</key>
  <string>$(DEV_SERVER_URL)</string>
  <key>NSCameraUsageDescription</key>
  <string>${name} uses the camera to capture photos and video.</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>${name} uses the microphone to record audio.</string>
  <key>NSLocationUsageDescription</key>
  <string>${name} uses your location to show location-aware content.</string>
</dict>
</plist>
`)

      // macos/Sources/App.entitlements
      //
      // Wired in through CODE_SIGN_ENTITLEMENTS, and it does real work: it pins
      // App Sandbox off. FileSystemModule writes to arbitrary paths, the dev
      // host opens a ws://localhost:8174 socket and CameraModule/GeolocationModule
      // reach device hardware — under the sandbox each of those needs its own
      // entitlement (network.client, files.user-selected.read-write,
      // device.camera) or the call fails at runtime. Sandboxing is a
      // distribution decision, so the scaffold states the non-sandboxed default
      // explicitly in one editable place instead of leaving it implicit.
      await writeFile(join(macosSrcDir, 'App.entitlements'), `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <false/>
</dict>
</plist>
`)

      // macos/Sources/main.swift
      //
      // A programmatic entry point rather than `@main` on the delegate: the
      // generated host has no nib or storyboard, and `NSApplicationMain` would
      // have nothing to load. This keeps the whole macOS host code-generated
      // and diffable, with no .xib to keep in sync.
      await writeFile(join(macosSrcDir, 'main.swift'), `import AppKit

// Retained for the process lifetime: NSApplication.delegate is weak, and
// top-level bindings in main.swift live as long as the executable does.
let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate

// Nothing reads an activation policy out of a nib here, so state it: the app
// owns a Dock item and should come to the front when \`vue-native run macos\`
// launches it with \`open\`.
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
`)

      // macos/Sources/AppDelegate.swift
      await writeFile(join(macosSrcDir, 'AppDelegate.swift'), `import AppKit
import VueNativeMacOS

/// Application delegate for the generated macOS host.
///
/// Subclassing \`VueNativeAppDelegate\` instead of implementing
/// \`NSApplicationDelegate\` directly is what installs a main menu at launch.
/// A programmatically launched \`NSApplication\` otherwise gets an *empty* menu
/// bar, and AppKit routes key equivalents through the main menu — so without
/// it Cmd+Q does not quit and Cmd+C/V/X/A never reach a focused \`VInput\`.
///
/// Override \`makeMainMenu()\` to replace or extend the standard App / Edit /
/// View / Window / Help menu. \`useMenu()\` merges into whatever is installed.
class AppDelegate: VueNativeAppDelegate {
    override func createWindowController() -> VueNativeWindowController {
        MainWindowController()
    }
}
`)

      // macos/Sources/MainWindowController.swift
      await writeFile(join(macosSrcDir, 'MainWindowController.swift'), `import Foundation
import VueNativeMacOS

/// Hosts the Vue app in the application's main window.
///
/// \`NativeBridge.shared\` and \`JSRuntime.shared\` are process-wide singletons, so
/// this is the app's one and only Vue surface — a second window controller
/// would tear the first one's registry down rather than render a second app.
final class MainWindowController: VueNativeWindowController {
    /// Matches the resource copied in by macos/project.yml
    /// (../dist/vue-native-bundle.js -> Contents/Resources/vue-native-bundle.js).
    override var bundleName: String { "vue-native-bundle" }

    #if DEBUG
    /// \`vue-native dev --platform macos\` serves the rebuilt bundle here.
    /// A production build skips the connection entirely.
    ///
    /// Injected at build time from the DEV_SERVER_URL build setting, which
    /// \`vue-native run macos --port\` overrides on the xcodebuild command line;
    /// the literal fallback keeps hand-written hosts working.
    override var devServerURL: URL? {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "VueNativeDevServerURL") as? String,
           !configured.isEmpty,
           let url = URL(string: configured) {
            return url
        }
        return URL(string: "ws://localhost:8174")
    }
    #endif
}
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
    minSdk: 21,
    targetSdk: 35,
  },
  macos: {
    deploymentTarget: '${MACOS_DEPLOYMENT_TARGET}',
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
declare const __PLATFORM__: 'ios' | 'android' | 'macos'
`)

      // .gitignore
      await writeFile(join(dir, '.gitignore'), `node_modules/
dist/
*.xcuserstate
*.xcuserdatad/
DerivedData/
.build/
build/
ios/*.xcodeproj/
ios/*.xcworkspace/
macos/*.xcodeproj/
macos/*.xcworkspace/
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

      p.log.success('Project created successfully!')
      p.note(
        [
          `cd ${name}`,
          'bun install',
          'vue-native dev',
          '',
          'Run on iOS:     vue-native run ios',
          'Run on Android: vue-native run android',
          '                (or open android/ in Android Studio)',
          'Run on macOS:   vue-native run macos',
          '                (needs XcodeGen: brew install xcodegen)',
        ].join('\n'),
        'Next steps',
      )
      p.outro('Happy building!')
    } catch (err) {
      throw new ConfigError(
        `Error creating project: ${(err as Error).message}`,
      )
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
