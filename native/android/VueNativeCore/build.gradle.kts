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
    compileSdk = 35

    defaultConfig {
        minSdk = 21
        targetSdk = 35

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("consumer-rules.pro")
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
        // ImageProxy.image (used by the QR scanner's ML Kit frame analysis) is
        // marked @ExperimentalGetImage; opt in at the module level rather than
        // annotating every call site.
        freeCompilerArgs += listOf("-opt-in=androidx.camera.core.ExperimentalGetImage")
    }

    // Allow lint checks to pass without strict enforcement during development
    lint {
        abortOnError = false
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
    }
}

dependencies {
    // AndroidX Core
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.recyclerview:recyclerview:1.3.2")
    implementation("androidx.webkit:webkit:1.10.0")
    implementation("androidx.swiperefreshlayout:swiperefreshlayout:1.1.0")

    // J2V8 — JavaScript engine (V8 for Android)
    implementation("com.eclipsesource.j2v8:j2v8:6.2.1@aar")

    // FlexboxLayout — CSS Flexbox for Android views
    implementation("com.google.android.flexbox:flexbox:3.0.0")

    // Coil — Image loading
    implementation("io.coil-kt:coil:2.7.0")

    // AndroidSVG — SVG rendering (VSVG component)
    implementation("com.caverock:androidsvg:1.4")

    // OkHttp — HTTP for fetch polyfill
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    // Kotlin Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    // Lifecycle Process (for ProcessLifecycleOwner)
    implementation("androidx.lifecycle:lifecycle-process:2.7.0")

    // WorkManager (for BackgroundTaskModule)
    implementation("androidx.work:work-runtime-ktx:2.8.1")

    // Location (for GeolocationModule)
    implementation("com.google.android.gms:play-services-location:21.1.0")

    // Biometry (for BiometryModule)
    implementation("androidx.biometric:biometric:1.1.0")

    // Secure Storage (for SecureStorageModule)
    implementation("androidx.security:security-crypto:1.1.0-alpha06")

    // Google Play Billing (for IAPModule)
    implementation("com.android.billingclient:billing:7.0.0")

    // Credential Manager + Google Identity (for SocialAuthModule)
    implementation("androidx.credentials:credentials:1.2.2")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")

    // CameraX — live preview + frame analysis for Camera.scanQRCode.
    // Pinned to 1.4.2 (not the newer 1.5.x/1.6.x lines): those require
    // compileSdk 36 and AGP 8.9+, both ahead of this project's compileSdk 35 /
    // AGP 8.2.2. 1.4.2 is the latest stable release compatible with both.
    implementation("androidx.camera:camera-camera2:1.4.2")
    implementation("androidx.camera:camera-lifecycle:1.4.2")
    implementation("androidx.camera:camera-view:1.4.2")

    // ML Kit Barcode Scanning — bundled model, no Google Play Services required
    // (see https://developers.google.com/ml-kit/vision/barcode-scanning/android)
    implementation("com.google.mlkit:barcode-scanning:17.3.0")

    // Testing
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.11.1")
    testImplementation("androidx.test:core:1.5.0")
    testImplementation("androidx.test.ext:junit:1.1.5")
    testImplementation("io.mockk:mockk:1.13.9")
    testImplementation("com.google.truth:truth:1.1.5")
}

ktlint {
    android.set(true)
    outputToConsole.set(true)
    ignoreFailures.set(false)
    filter {
        exclude("**/generated/**")
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
