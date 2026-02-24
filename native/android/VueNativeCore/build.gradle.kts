plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("maven-publish")
}

android {
    namespace = "com.vuenative.core"
    compileSdk = 34

    defaultConfig {
        minSdk = 21
        targetSdk = 34

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
    }

    // Allow lint checks to pass without strict enforcement during development
    lint {
        abortOnError = false
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
}

afterEvaluate {
    publishing {
        publications {
            create<MavenPublication>("release") {
                groupId = "com.vuenative"
                artifactId = "core"
                version = "0.4.4"
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
