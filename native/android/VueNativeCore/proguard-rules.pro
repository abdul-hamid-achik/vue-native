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

# Biometric
-keep class androidx.biometric.** { *; }

# SwipeRefreshLayout
-keep class androidx.swiperefreshlayout.** { *; }
