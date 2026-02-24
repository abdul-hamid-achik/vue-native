# Android Setup — Build & Run on Emulator

This guide walks through every step to get a Vue Native app building and running on the Android Emulator, from prerequisites to hot reload.

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| **Android Studio** | Ladybug+ | [developer.android.com/studio](https://developer.android.com/studio) |
| **Android SDK** | API 35 | Via Android Studio SDK Manager |
| **JDK** | 17 | Bundled with Android Studio |
| **Bun** (or Node 18+) | 1.3+ | `curl -fsSL https://bun.sh/install \| bash` |

### Android Studio setup

After installing Android Studio:

1. Open **Settings > Languages & Frameworks > Android SDK**
2. Under **SDK Platforms**, check **Android 15 (API 35)**
3. Under **SDK Tools**, check:
   - **Android SDK Build-Tools 35.x**
   - **Android Emulator**
   - **Android SDK Platform-Tools**
4. Click **Apply** to download

### Set ANDROID_HOME

Add to your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
export ANDROID_HOME=$HOME/Library/Android/sdk   # macOS
export PATH=$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH
```

Reload your shell: `source ~/.zshrc`

### Create an emulator

1. In Android Studio: **Tools > Device Manager > Create Virtual Device**
2. Pick a device (e.g. Pixel 8)
3. Select a system image:
   - **API 35**, **x86_64** (Intel/AMD) or **arm64** (Apple Silicon)
4. Finish

Or via CLI:

```bash
sdkmanager "system-images;android-35;google_apis;arm64-v8a"
avdmanager create avd -n Pixel8 -k "system-images;android-35;google_apis;arm64-v8a"
```

Verify:

```bash
emulator -list-avds        # should list your AVD
adb --version              # Android Debug Bridge
```

## Quick start (CLI)

The fastest path — the CLI handles everything:

```bash
# 1. Scaffold project
npx @thelacanians/vue-native-cli create my-app
cd my-app
bun install

# 2. Boot emulator (in background)
emulator -avd Pixel8 &

# 3. Build JS bundle + build APK + install + launch
vue-native run android
```

`vue-native run android` does all of the following automatically:
1. Runs `vite build` to produce `dist/vue-native-bundle.js`
2. Copies the bundle to `android/app/src/main/assets/`
3. Runs `./gradlew assembleDebug`
4. Installs the APK via `adb install`
5. Launches the app via `adb shell am start`

If you want to understand what happens under the hood, read on.

## Step-by-step (manual)

### 1. Create and scaffold

```bash
npx @thelacanians/vue-native-cli create my-app
cd my-app
bun install
```

This generates:

```
my-app/
  app/                           # Vue 3 source
    main.ts
    App.vue
    pages/Home.vue
  android/                       # Native Gradle project
    build.gradle.kts             # Root Gradle config (AGP 8.7.3, Kotlin 2.0.21)
    settings.gradle.kts          # Includes :app, repositories
    gradle.properties            # JVM args, AndroidX flags
    gradle/wrapper/              # Gradle 8.11.1 wrapper
    gradlew                      # Gradle wrapper script
    app/
      build.gradle.kts           # App module: compileSdk 35, minSdk 24
      proguard-rules.pro
      src/main/
        AndroidManifest.xml
        assets/                  # JS bundle goes here
        kotlin/.../MainActivity.kt
        res/values/strings.xml
        res/values/themes.xml
        res/xml/network_security_config.xml
      src/debug/res/xml/
        network_security_config.xml  # Allows cleartext for dev server
  dist/                          # Built JS bundle (generated)
  vite.config.ts
  vue-native.config.ts
  package.json
```

### 2. Build the JS bundle

```bash
bun run build
```

This runs Vite with the Vue Native plugin. It:
- Compiles `.vue` SFCs via `@vitejs/plugin-vue`
- Aliases `vue` imports to `@thelacanians/vue-native-runtime` (the native renderer)
- Outputs a single IIFE file: `dist/vue-native-bundle.js`
- Target: ES2020 (V8/J2V8 on Android supports this)

### 3. Copy the bundle to assets

```bash
mkdir -p android/app/src/main/assets
cp dist/vue-native-bundle.js android/app/src/main/assets/
```

::: tip Automate this
Add a Gradle task to copy the bundle automatically before each build:

```kotlin
// android/app/build.gradle.kts
tasks.register<Copy>("copyJsBundle") {
    from("../../dist/vue-native-bundle.js")
    into("src/main/assets")
}
tasks.named("preBuild") { dependsOn("copyJsBundle") }
```
:::

### 4. Build the APK

```bash
cd android
./gradlew assembleDebug
```

This:
- Downloads Gradle 8.11.1 (first run only)
- Resolves dependencies from Google, Maven Central, JitPack, and GitHub Packages
- Compiles Kotlin sources
- Links the VueNativeCore library
- Packages the JS bundle from `assets/`
- Signs with the debug keystore
- Outputs: `app/build/outputs/apk/debug/app-debug.apk`

::: tip First build is slow
The first build downloads Gradle + all dependencies (~2-3 min). Subsequent builds are incremental and much faster.
:::

### 5. Boot the emulator

```bash
# Start the emulator in background
emulator -avd Pixel8 &

# Wait for it to be ready
adb wait-for-device
```

### 6. Install and launch

```bash
# Install the APK
adb install -r android/app/build/outputs/apk/debug/app-debug.apk

# Launch the app
adb shell am start -n "com.vuenative.myapp/.MainActivity"
```

Your app should appear on the emulator.

## Using Android Studio directly

You can also build and run from Android Studio's GUI:

1. Open the `android/` directory as a project
2. Wait for Gradle sync to complete
3. Select your emulator from the device dropdown (top toolbar)
4. Click the **Run** button (green triangle) or press **Shift+F10**

Android Studio handles the build, install, and launch. Logcat (bottom pane) shows `[VueNative]` log output.

## Hot reload

Hot reload lets you edit `.vue` files and see changes instantly without rebuilding the APK.

### Setup

**Terminal 1 — Start the dev server:**

```bash
bun run dev
```

This starts:
- Vite in watch mode (rebuilds `dist/vue-native-bundle.js` on every save)
- A WebSocket server on `ws://localhost:8174`

**Terminal 2 — Run the app** (first time only):

```bash
vue-native run android
```

Or build from Android Studio. Once the app is running, you don't need to rebuild — changes are pushed via WebSocket.

### How it works

1. You save `app/pages/Home.vue`
2. Vite detects the change, rebuilds `vue-native-bundle.js`
3. The dev server sends the new bundle over WebSocket
4. `HotReloadManager` in the app receives it
5. `JSRuntime` tears down the old V8 context, creates a new one, evaluates the new bundle
6. UI updates on screen

### Emulator networking

The Android emulator maps `10.0.2.2` to the host machine's `localhost`. The scaffolded `MainActivity.kt` already has this configured:

```kotlin
class MainActivity : VueNativeActivity() {
    override fun getBundleAssetPath() = "vue-native-bundle.js"

    override fun getDevServerUrl(): String? {
        return if (BuildConfig.DEBUG) "ws://10.0.2.2:8174" else null
    }
}
```

For a **physical device** on the same WiFi network, use your machine's LAN IP:

```kotlin
override fun getDevServerUrl(): String? {
    return if (BuildConfig.DEBUG) "ws://192.168.1.100:8174" else null
}
```

Or use `adb reverse` to forward ports over USB:

```bash
adb reverse tcp:8174 tcp:8174
# Now the device can connect to ws://localhost:8174
```

## Debugging

### Logcat

All `console.log()` / `console.error()` calls from your Vue code appear in Logcat:

```bash
# Filter to Vue Native logs
adb logcat -s VueNative-JSRuntime:* VueNative-Bridge:* VueNative-HotReload:*
```

Or in Android Studio: open the **Logcat** tab and filter by `VueNative`.

### Error overlay

In debug builds, unhandled JS errors display a red overlay on screen with the error message and stack trace.

### Checking the bundle loaded

If you see a white screen, verify the bundle is executing:

```ts
// Add to the top of app/main.ts
console.log('Bundle executing')
```

Then check Logcat. If you see the log, the bundle loaded. If not, check:
- The bundle exists at `android/app/src/main/assets/vue-native-bundle.js`
- `bun run build` completed without errors

### Useful adb commands

```bash
# List connected devices/emulators
adb devices

# View all logs (verbose)
adb logcat

# Clear logcat
adb logcat -c

# Take a screenshot
adb exec-out screencap -p > ~/Desktop/screenshot.png

# Open a URL (deep linking)
adb shell am start -a android.intent.action.VIEW -d "myapp://settings"

# Uninstall the app
adb uninstall com.vuenative.myapp

# Forward ports (for physical device hot reload)
adb reverse tcp:8174 tcp:8174
```

## Common issues

**"SDK location not found"** — Create `android/local.properties`:

```properties
sdk.dir=/Users/yourname/Library/Android/sdk
```

Or set the `ANDROID_HOME` environment variable (see [Prerequisites](#prerequisites)).

**"Could not resolve com.eclipsesource.j2v8:j2v8"** — J2V8 is hosted on JitPack. Verify `jitpack.io` is in the repositories block in `settings.gradle.kts`:

```kotlin
maven { url = uri("https://jitpack.io") }
```

**White screen** — The most likely causes:
1. Bundle not copied to `assets/` — run `bun run build` then copy
2. Dev server URL incorrect — emulator uses `10.0.2.2`, not `localhost`
3. Check Logcat for `[VueNative]` errors

**"INSTALL_FAILED_NO_MATCHING_ABIS"** — CPU architecture mismatch. Use an **x86_64** system image on Intel/AMD, or **arm64** on Apple Silicon. Check your emulator image matches your machine.

**Emulator can't connect to dev server** — The emulator uses `10.0.2.2` to reach the host. Verify:
1. `bun run dev` is running on the host
2. Nothing else is using port 8174: `lsof -i :8174`
3. `getDevServerUrl()` returns `"ws://10.0.2.2:8174"`

**Gradle build OOM** — Increase heap in `gradle.properties`:

```properties
org.gradle.jvmargs=-Xmx4096m
```

**Dependency conflicts** — Inspect the dependency tree:

```bash
cd android && ./gradlew :app:dependencies
```

See the [Troubleshooting](/guide/troubleshooting.md) guide for more.
