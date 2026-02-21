plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
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

    // Location (for GeolocationModule)
    implementation("com.google.android.gms:play-services-location:21.1.0")

    // Biometry (for BiometryModule)
    implementation("androidx.biometric:biometric:1.1.0")
}
