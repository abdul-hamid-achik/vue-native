# Android Setup

## New project

```bash
npx @thelacanians/vue-native-cli create my-app
cd my-app
bun install
```

Open `android/` in Android Studio and run on an emulator or device.

## Add to existing Android project

### 1. Add the library module

In `settings.gradle.kts`:

```kotlin
include(":VueNativeCore")
project(":VueNativeCore").projectDir = File("../native/android/VueNativeCore")
```

In `app/build.gradle.kts`:

```kotlin
dependencies {
    implementation(project(":VueNativeCore"))
}
```

### 2. Add JitPack (for J2V8)

In `settings.gradle.kts` repositories:

```kotlin
maven { url = uri("https://jitpack.io") }
```

### 3. Copy the JS bundle

Place `dist/vue-native-bundle.js` in `app/src/main/assets/`.

Automate with a Gradle task:

```kotlin
// app/build.gradle.kts
tasks.register<Copy>("copyJsBundle") {
    from("../../dist/vue-native-bundle.js")
    into("src/main/assets")
}
tasks.named("preBuild") { dependsOn("copyJsBundle") }
```

### 4. Extend VueNativeActivity

```kotlin
// MainActivity.kt
import com.vuenative.core.VueNativeActivity

class MainActivity : VueNativeActivity() {
    override fun getBundleAssetPath() = "vue-native-bundle.js"
}
```

### 5. AndroidManifest.xml

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:windowSoftInputMode="adjustResize">
    <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
    </intent-filter>
</activity>
```

## Permissions

Add to `AndroidManifest.xml` as needed:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```
