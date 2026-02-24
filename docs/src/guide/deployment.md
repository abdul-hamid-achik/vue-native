# Deployment & App Store Submission

This guide walks through the full process of building a Vue Native app for production and submitting it to the Apple App Store and Google Play Store.

## Building for Production

### Creating the Production Bundle

The Vue Native build system uses Vite with a custom plugin to produce an optimized IIFE bundle that runs in JavaScriptCore (iOS) or J2V8 (Android).

```bash
bun run build
```

This runs the Vite build with the `@vue-native/vite-plugin`, which:

- Compiles your Vue 3 SFCs into render functions
- Tree-shakes unused exports from `@vue-native/runtime`
- Minifies the output with esbuild
- Produces a single `dist/vue-native-bundle.js` file in IIFE format

::: tip
The plugin targets ES2020 for compatibility with iOS 16+ JavaScriptCore. Dynamic imports are inlined (`inlineDynamicImports: true`) since native JS engines do not support ESM.
:::

### Verifying Bundle Size

After building, check the output size:

```bash
ls -lh dist/vue-native-bundle.js
```

A typical Vue Native app with a few screens, navigation, and several composables produces a bundle between 80-200 KB minified. If your bundle is significantly larger, check for:

- Large third-party libraries being bundled (consider native module alternatives)
- Unused composables or components that are not being tree-shaken
- Embedded data (images, JSON) that should be loaded at runtime instead

### Bundle Optimization Tips

1. **Import only what you use.** The runtime is fully tree-shakeable. Importing `useCamera` when you do not use it has zero cost, as long as you do not reference it.

2. **Externalize large data.** Load JSON datasets, configuration, and image assets from the network or native file system rather than inlining them.

3. **Check the Vite build output.** Run `bun run build --mode production` and examine the output for any unexpected inclusions. Vite logs the chunk sizes after each build.

4. **Enable source maps only for debugging.** Production builds disable source maps by default. If you enable them for crash reporting, keep the `.map` file on your server -- do not ship it in the app bundle.

## iOS App Store Submission

### Prerequisites

- An [Apple Developer Program](https://developer.apple.com/programs/) membership ($99/year)
- Xcode 15 or later installed
- A physical Mac (Xcode cannot run on other platforms)

### Step 1: Configure Signing

Open your project in Xcode (`ios/` directory) and configure signing under **Signing & Capabilities**:

1. Select your **Team** (your Apple Developer account)
2. Set a unique **Bundle Identifier** (e.g., `com.yourcompany.yourapp`)
3. Enable **Automatically manage signing** for the simplest setup

For CI/CD or manual signing:

```
Xcode → Build Settings → Code Signing Identity → Apple Distribution
Xcode → Build Settings → Provisioning Profile → Your App Store profile
```

::: warning
You need a separate provisioning profile for App Store distribution. Development profiles will not work for submission. Create one in the [Apple Developer portal](https://developer.apple.com/account/resources/profiles/list) under **Certificates, Identifiers & Profiles**.
:::

### Step 2: Set App Icons

App icons go in the Xcode asset catalog at `ios/YourApp/Assets.xcassets/AppIcon.appiconset/`. You need a single 1024x1024 PNG icon, and Xcode 15+ will automatically generate all required sizes.

If you are on an older Xcode version, you need these sizes:

| Size (px) | Usage |
|-----------|-------|
| 20x20 | iPad Notifications @1x |
| 40x40 | iPhone/iPad Notifications @2x, iPad Spotlight @1x |
| 60x60 | iPhone Notifications @3x |
| 58x58 | iPhone Settings @2x |
| 76x76 | iPad App @1x |
| 80x80 | iPad Spotlight @2x |
| 87x87 | iPhone Settings @3x |
| 120x120 | iPhone App @2x, iPhone Spotlight @3x |
| 152x152 | iPad App @2x |
| 167x167 | iPad Pro App @2x |
| 180x180 | iPhone App @3x |
| 1024x1024 | App Store |

### Step 3: Configure the Launch Screen

Use a `LaunchScreen.storyboard` (Xcode's default) or configure a launch screen in your `Info.plist`:

```xml
<key>UILaunchStoryboardName</key>
<string>LaunchScreen</string>
```

Keep the launch screen simple -- a solid background color with your app logo centered works well and avoids layout issues across device sizes.

### Step 4: Required Info.plist Keys

Apple requires usage description strings for any sensitive APIs your app accesses. If you use any of the following composables, you **must** include the corresponding `Info.plist` key:

| Composable | Info.plist Key | Example Value |
|------------|----------------|---------------|
| `useCamera` | `NSCameraUsageDescription` | "This app uses the camera to take photos." |
| `useCamera` (video) | `NSMicrophoneUsageDescription` | "This app records audio with video." |
| `useGeolocation` | `NSLocationWhenInUseUsageDescription` | "This app uses your location to show nearby places." |
| `useGeolocation` (always) | `NSLocationAlwaysUsageDescription` | "This app tracks your location in the background." |
| `useContacts` | `NSContactsUsageDescription` | "This app accesses contacts to help you share with friends." |
| `useCalendar` | `NSCalendarsUsageDescription` | "This app accesses your calendar to schedule events." |
| `useCamera` (gallery) | `NSPhotoLibraryUsageDescription` | "This app accesses your photos to let you choose a profile picture." |
| `useBluetooth` | `NSBluetoothAlwaysUsageDescription` | "This app uses Bluetooth to connect to nearby devices." |
| `useBiometry` | `NSFaceIDUsageDescription` | "This app uses Face ID for secure authentication." |
| `useNotifications` | (no plist key needed -- runtime permission prompt) | -- |

Add these to your `Info.plist`:

```xml
<dict>
    <!-- Only include keys for APIs you actually use -->
    <key>NSCameraUsageDescription</key>
    <string>This app uses the camera to take photos.</string>

    <key>NSLocationWhenInUseUsageDescription</key>
    <string>This app uses your location to show nearby places.</string>

    <key>NSPhotoLibraryUsageDescription</key>
    <string>This app accesses your photo library.</string>
</dict>
```

::: danger
Submitting an app with a missing usage description for an API you call will cause an immediate rejection. Apple scans your binary for API usage and cross-references it with your `Info.plist`.
:::

### Step 5: Set Version and Build Number

In your Xcode project or `Info.plist`:

```xml
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>
<key>CFBundleVersion</key>
<string>1</string>
```

- `CFBundleShortVersionString` is the user-visible version (e.g., `1.0.0`)
- `CFBundleVersion` is the build number -- increment this for every upload to App Store Connect

### Step 6: Build the Archive

1. Build the JS bundle first:

```bash
bun run build
```

2. Open the Xcode project:

```bash
open ios/YourApp.xcodeproj
# or if using a workspace:
open ios/YourApp.xcworkspace
```

3. Select **Any iOS Device (arm64)** as the build destination
4. Go to **Product > Archive**
5. Wait for the build to complete -- the Organizer window opens automatically

The build script in your Xcode project should automatically copy `dist/vue-native-bundle.js` into the app bundle at build time.

### Step 7: Submit via App Store Connect

1. In the Xcode Organizer, select your archive and click **Distribute App**
2. Choose **App Store Connect** and follow the prompts
3. After uploading, go to [App Store Connect](https://appstoreconnect.apple.com)
4. Create a new app listing if this is your first submission
5. Fill in the required metadata: description, screenshots, keywords, support URL, privacy policy URL
6. Select the uploaded build under the **Build** section
7. Submit for review

### Common iOS Rejection Reasons

| Reason | How to Avoid |
|--------|--------------|
| **Missing privacy descriptions** | Add all required `NS*UsageDescription` keys (see Step 4) |
| **Crashes on launch** | Test on a real device before submitting. Ensure the JS bundle is included in the archive. |
| **Incomplete metadata** | Fill in all required fields in App Store Connect, including screenshots for all required device sizes |
| **Missing privacy policy** | Provide a privacy policy URL, even for simple apps |
| **Guideline 4.2 -- Minimum functionality** | Ensure your app provides meaningful value beyond a simple wrapper |
| **Guideline 2.1 -- Performance** | Test on older devices (iPhone SE, iPad mini). Ensure the app does not freeze or consume excessive memory. |
| **Login required but no test account** | Provide demo credentials in the App Review notes field |

## Google Play Submission

### Prerequisites

- A [Google Play Developer account](https://play.google.com/console/) ($25 one-time fee)
- Android Studio installed
- JDK 17 or later

### Step 1: Configure Release Signing

Generate a release keystore:

```bash
keytool -genkeypair \
  -v \
  -storetype PKCS12 \
  -keystore release.keystore \
  -alias my-app-key \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

::: warning
Keep your keystore file and passwords safe. If you lose them, you cannot update your app on Google Play. Consider using [Google Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756) to let Google manage your signing key.
:::

Add the signing configuration to `android/app/build.gradle.kts`:

```kotlin
android {
    signingConfigs {
        create("release") {
            storeFile = file("release.keystore")
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: ""
            keyAlias = System.getenv("KEY_ALIAS") ?: "my-app-key"
            keyPassword = System.getenv("KEY_PASSWORD") ?: ""
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

::: tip
Never hardcode keystore passwords in your build files. Use environment variables or a `local.properties` file (which should be in `.gitignore`).
:::

### Step 2: Set App Icons

Place your launcher icons in the mipmap resource directories:

```
android/app/src/main/res/
  mipmap-mdpi/ic_launcher.png       (48x48)
  mipmap-hdpi/ic_launcher.png       (72x72)
  mipmap-xhdpi/ic_launcher.png      (96x96)
  mipmap-xxhdpi/ic_launcher.png     (144x144)
  mipmap-xxxhdpi/ic_launcher.png    (192x192)
```

Also provide round icons in matching `mipmap-*` directories as `ic_launcher_round.png`. These are referenced in the `AndroidManifest.xml`:

```xml
<application
    android:icon="@mipmap/ic_launcher"
    android:roundIcon="@mipmap/ic_launcher_round"
    ...>
```

Use Android Studio's **Image Asset Studio** (**File > New > Image Asset**) to generate all sizes from a single source image.

### Step 3: Set Version Information

In `android/app/build.gradle.kts`:

```kotlin
android {
    defaultConfig {
        applicationId = "com.yourcompany.yourapp"
        versionCode = 1        // Increment for every upload
        versionName = "1.0.0"  // User-visible version
    }
}
```

### Step 4: Configure Permissions

Add required permissions to `android/app/src/main/AndroidManifest.xml` based on the composables your app uses:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Always needed for Vue Native apps -->
    <uses-permission android:name="android.permission.INTERNET" />

    <!-- Add only the permissions your app needs -->
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.READ_CONTACTS" />
    <uses-permission android:name="android.permission.WRITE_CONTACTS" />
    <uses-permission android:name="android.permission.READ_CALENDAR" />
    <uses-permission android:name="android.permission.WRITE_CALENDAR" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

    <application ...>
</manifest>
```

::: warning
Only declare permissions your app actually uses. Google Play flags apps that request unnecessary permissions, and users see all requested permissions before installing.
:::

### Step 5: Network Security Configuration

Vue Native projects include a network security configuration that allows cleartext traffic only to localhost (for development hot reload). This is already set up correctly for production:

```xml
<!-- android/app/src/main/res/xml/network_security_config.xml -->
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">localhost</domain>
        <domain includeSubdomains="true">127.0.0.1</domain>
        <domain includeSubdomains="true">10.0.2.2</domain>
    </domain-config>
</network-security-config>
```

This configuration blocks cleartext HTTP for all domains except local development servers, which is what Google Play expects. No changes are needed for production.

### Step 6: Build the Release AAB

1. Build the JS bundle:

```bash
bun run build
```

2. Copy the bundle to the Android assets directory (or use the automated Gradle task from the [build guide](./build.md)):

```bash
cp dist/vue-native-bundle.js android/app/src/main/assets/
```

3. Build the release Android App Bundle:

```bash
cd android
./gradlew bundleRelease
```

The output AAB file is at:

```
android/app/build/outputs/bundle/release/app-release.aab
```

::: tip
Google Play requires AAB (Android App Bundle) format, not APK. The AAB format lets Google generate optimized APKs for each device configuration, reducing download size for your users.
:::

### Step 7: Submit via Google Play Console

1. Go to [Google Play Console](https://play.google.com/console/)
2. Create a new app or select an existing one
3. Complete the **Dashboard** setup checklist:
   - App details (name, description, category)
   - Store listing (screenshots, feature graphic, short/full description)
   - Content rating questionnaire
   - Pricing and distribution
   - Data safety form
   - Target audience and content
4. Navigate to **Release > Production > Create new release**
5. Upload the `app-release.aab` file
6. Add release notes
7. Review and submit for review

### Common Google Play Rejection Reasons

| Reason | How to Avoid |
|--------|--------------|
| **Missing Data Safety form** | Complete the Data Safety section in Google Play Console, declaring all data your app collects |
| **Excessive permissions** | Only declare permissions your app uses. Remove unused permission declarations. |
| **Target API level too low** | Set `targetSdk = 34` (or the current requirement) in `build.gradle.kts` |
| **Crashes on launch** | Test on multiple emulator configurations. Ensure the JS bundle is in `assets/`. |
| **Missing privacy policy** | Provide a privacy policy URL in the store listing |
| **Deceptive behavior** | Be transparent about what data you collect and how. Match your Data Safety declaration. |
| **Content rating missing** | Complete the content rating questionnaire |

## OTA Updates (Post-Release)

Once your app is live, you can ship JavaScript bundle updates without going through store review using the `useOTAUpdate` composable. OTA updates only affect the JS bundle -- native code changes still require a store update.

```ts
import { useOTAUpdate } from '@vue-native/runtime'

const { checkForUpdate, downloadUpdate, applyUpdate } = useOTAUpdate(
  'https://updates.yourapp.com/api/check'
)

// Check, download, and apply in one flow
const info = await checkForUpdate()
if (info.updateAvailable) {
  await downloadUpdate()
  await applyUpdate()
  // New bundle loads on next app launch
}
```

OTA updates include SHA-256 hash verification to ensure bundle integrity. The native module verifies the hash before saving the downloaded bundle.

::: tip
OTA updates are ideal for bug fixes, UI tweaks, and feature additions that do not require new native code. For changes that add new native modules or update native dependencies, you must submit a new version through the app stores.
:::

For full API documentation, see the [useOTAUpdate composable reference](/composables/useOTAUpdate.md).

## Deployment Checklist

Before submitting to either store, verify:

- [ ] `bun run build` completes without errors
- [ ] The app runs correctly with the production bundle on a real device
- [ ] All required privacy/permission descriptions are configured
- [ ] App icons are set for all required sizes
- [ ] Version number and build number are set correctly
- [ ] Launch screen / splash screen is configured
- [ ] The app does not log sensitive data in production (check `console.log` usage)
- [ ] Network requests use HTTPS (except localhost for dev)
- [ ] A privacy policy URL is ready
- [ ] Store listing metadata (description, screenshots, keywords) is prepared
