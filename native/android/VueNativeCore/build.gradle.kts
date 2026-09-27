import org.gradle.api.file.DuplicatesStrategy
import org.gradle.jvm.tasks.Jar

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("maven-publish")
    id("org.jlleitschuh.gradle.ktlint")
}

// Single source of truth for the published version: packages/runtime/package.json.
// Falls back to 0.0.0-SNAPSHOT when the JS workspace isn't present (standalone Android builds).
val publishedVersion: String = run {
    val pkgJson = rootProject.file("../../packages/runtime/package.json")
    if (!pkgJson.exists()) {
        "0.0.0-SNAPSHOT"
    } else {
        Regex("\"version\"\\s*:\\s*\"([^\"]+)\"")
            .find(pkgJson.readText())
            ?.groupValues?.get(1)
            ?: "0.0.0-SNAPSHOT"
    }
}

android {
    namespace = "com.vuenative.core"
    compileSdk = libs.versions.compileSdk.get().toInt()

    defaultConfig {
        minSdk = libs.versions.minSdk.get().toInt()
        targetSdk = libs.versions.targetSdk.get().toInt()

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("consumer-rules.pro")
    }

    buildTypes {
        release {
            // Deliberately false: an Android *library* must not be minified —
            // that would rename the API host apps compile against. The rules that
            // protect a minified HOST build are in consumer-rules.pro, which
            // ships inside the AAR.
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
        // ImageProxy.image (used by the QR scanner's ML Kit frame analysis) is
        // marked @ExperimentalGetImage; opt in at the module level rather than
        // annotating every call site.
        freeCompilerArgs += listOf("-opt-in=androidx.camera.core.ExperimentalGetImage")
    }

    lint {
        // Lint is a real gate now. It used to be abortOnError = false, which is
        // exactly why a NewApi violation (ConnectivityManager.getActiveNetwork()
        // on API 23 with minSdk 21, in NetworkModule) shipped unnoticed — and CI
        // never ran Android Lint at all.
        abortOnError = true
        warningsAsErrors = false
        // Pre-existing findings that are not fixed in this pass are recorded here
        // so the build stays green while new violations fail. Regenerate with:
        //   ./gradlew :VueNativeCore:updateLintBaseline
        // Do not add NewApi to the baseline without an explicit SDK_INT guard.
        baseline = file("lint-baseline.xml")
        checkReleaseBuilds = true
        // androidx.camera.core.ExperimentalGetImage is opted into module-wide via
        // kotlinc's -opt-in flag (see kotlinOptions above). Lint's
        // UnsafeOptInUsage check does not read that compiler argument and
        // re-reports every ImageProxy.image call site up the whole call chain, so
        // it is disabled here rather than baselined — baseline entries for it
        // just move whenever the chain changes.
        disable += "UnsafeOptInUsageError"
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
    }
}

dependencies {
    // AndroidX Core
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.recyclerview)
    implementation(libs.androidx.webkit)
    implementation(libs.androidx.swiperefreshlayout)

    // J2V8 — JavaScript engine (V8 for Android)
    //
    // Deliberately NOT in gradle/libs.versions.toml: the `@aar` artifact-only
    // notation cannot be expressed in a version catalog, and dropping it would
    // start resolving J2V8's transitive dependencies into every host app.
    //
    // Bumped 6.2.1 -> 6.3.4 because 6.2.1's native libraries violate the 16 KB
    // page alignment Google Play requires for apps targeting Android 15+: of its
    // four ABIs, armeabi-v7a, x86 and x86_64 carry PT_LOAD segments whose file
    // offset and virtual address disagree modulo 16384 (verified by parsing the
    // ELF program headers of both published AARs; only arm64-v8a passed, which
    // is why this went unnoticed on real devices). 6.3.4 — the release upstream
    // made for exactly this, its issue #614 — aligns all four.
    //
    // Residual risk, stated plainly: this swaps the bundled V8 native library
    // under the whole bridge, and no test here executes it (Robolectric cannot
    // create a V8 isolate on the JVM and the app-shell smoke substitutes Rhino),
    // so compile + the Robolectric suite prove the Kotlin side only. Device
    // verification of JS execution remains outstanding.
    implementation("com.eclipsesource.j2v8:j2v8:6.3.4@aar")

    // FlexboxLayout — CSS Flexbox for Android views
    implementation(libs.flexbox)

    // Coil — Image loading
    implementation(libs.coil)

    // AndroidSVG — SVG rendering (VSVG component)
    implementation(libs.androidsvg)

    // OkHttp — HTTP for fetch polyfill
    implementation(libs.okhttp)

    // Kotlin Coroutines
    implementation(libs.kotlinx.coroutines.android)

    // Lifecycle Process (for ProcessLifecycleOwner)
    implementation(libs.androidx.lifecycle.process)

    // WorkManager (for BackgroundTaskModule)
    implementation(libs.androidx.work.runtime.ktx)

    // Location (for GeolocationModule)
    implementation(libs.play.services.location)

    // Biometry (for BiometryModule)
    implementation(libs.androidx.biometric)

    // Secure Storage (for SecureStorageModule)
    implementation(libs.androidx.security.crypto)

    // Google Play Billing (for IAPModule)
    implementation(libs.billing)

    // Credential Manager + Google Identity (for SocialAuthModule)
    implementation(libs.androidx.credentials)
    implementation(libs.googleid)

    // CameraX — live preview + frame analysis for Camera.scanQRCode.
    // Pinned to 1.4.2 (not the newer 1.5.x/1.6.x lines): those require
    // compileSdk 36 and AGP 8.9+, both ahead of this project's compileSdk 35 /
    // AGP 8.2.2. 1.4.2 is the latest stable release compatible with both.
    implementation(libs.androidx.camera.camera2)
    implementation(libs.androidx.camera.lifecycle)
    implementation(libs.androidx.camera.view)

    // ML Kit Barcode Scanning — bundled model, no Google Play Services required
    // (see https://developers.google.com/ml-kit/vision/barcode-scanning/android)
    implementation(libs.mlkit.barcode.scanning)

    // Testing
    testImplementation(libs.junit)
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.test.core)
    testImplementation(libs.androidx.test.ext.junit)
    testImplementation(libs.mockk)
    testImplementation(libs.truth)
    // Host-boot tests evaluate the committed JS fixture on the JVM. J2V8's
    // Android AAR cannot create a V8 isolate here.
    testImplementation(libs.rhino)
}

ktlint {
    android.set(true)
    outputToConsole.set(true)
    ignoreFailures.set(false)
    filter {
        exclude("**/generated/**")
    }
}

// The documented Android gate (AGENTS.md, root `bun run test:android`) is
// `:VueNativeCore:testDebugUnitTest`, which does NOT depend on lint — that is why
// turning abortOnError on would still have caught nothing in CI, and why the
// NetworkModule NewApi violation shipped. Wire lint into the test task so the
// gate that runs in CI is the gate that fails.
//
// Skip it locally with: ./gradlew :VueNativeCore:testDebugUnitTest -x lintDebug
//
// configureEach rather than tasks.named: AGP creates the unit-test tasks after
// this script is evaluated, so an eager lookup fails configuration.
tasks.configureEach {
    if (name == "testDebugUnitTest") {
        dependsOn("lintDebug")
    }
}

afterEvaluate {
    // AGP's generated release source archive receives src/main/kotlin through
    // overlapping source providers. Keep one copy of each physical source file.
    tasks.named<Jar>("releaseSourcesJar") {
        eachFile {
            duplicatesStrategy = DuplicatesStrategy.EXCLUDE
        }
    }

    publishing {
        publications {
            create<MavenPublication>("release") {
                groupId = "com.vuenative"
                artifactId = "core"
                version = publishedVersion
                from(components["release"])
            }
        }
        repositories {
            maven {
                name = "GitHubPackages"
                url = uri("https://maven.pkg.github.com/abdul-hamid-achik/vue-native")
                credentials {
                    username = System.getenv("GITHUB_ACTOR")
                    password = System.getenv("GITHUB_TOKEN")
                }
            }
        }
    }
}
