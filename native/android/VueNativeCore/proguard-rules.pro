# J2V8 — keep all V8 classes and JNI methods
-keep class com.eclipsesource.v8.** { *; }
-keepclasseswithmembers class com.eclipsesource.v8.** {
    native <methods>;
}

# FlexboxLayout
-keep class com.google.android.flexbox.** { *; }

# Coil image loading
-dontwarn coil.**

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# Kotlin serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

# Vue Native Core — keep all public API
-keep public class com.vuenative.core.VueNativeActivity { *; }
-keep public class com.vuenative.core.JSRuntime { *; }
-keep public class com.vuenative.core.NativeBridge { *; }
-keep public class com.vuenative.core.NativeModule { *; }
-keep public class com.vuenative.core.NativeModuleRegistry { *; }

# WorkManager — VueNativeWorker is constructed reflectively by
# PeriodicWorkRequestBuilder / OneTimeWorkRequestBuilder (BackgroundTaskModule).
# NOTE: this file only applies when the *library* is minified, and
# isMinifyEnabled is false. The rules that actually protect a minified HOST
# build live in consumer-rules.pro — keep the two in sync.
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.ListenableWorker
-keep public class * extends androidx.work.Worker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class com.vuenative.core.VueNativeWorker { <init>(...); }

# Component factories and modules are resolved by string name at runtime, so
# nothing references them statically.
-keep class * implements com.vuenative.core.NativeComponentFactory { *; }
-keep class * implements com.vuenative.core.NativeModule { *; }

# Biometric
-keep class androidx.biometric.** { *; }

# SwipeRefreshLayout
-keep class androidx.swiperefreshlayout.** { *; }
