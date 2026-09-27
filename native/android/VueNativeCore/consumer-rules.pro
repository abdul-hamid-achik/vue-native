# Consumer ProGuard rules for VueNativeCore library.
#
# These ship inside the AAR and are applied automatically to every app that
# depends on VueNativeCore. proguard-rules.pro (next to this file) only applies
# when the *library itself* is minified, which it is not — so this file is the
# only set of rules a minified host release build actually sees. Keep the two in
# sync.

# J2V8 — V8 engine JNI bindings must not be stripped or renamed: the native
# library resolves them by name at System.loadLibrary time.
-keep class com.eclipsesource.v8.** { *; }
-keepclasseswithmembers class com.eclipsesource.v8.** {
    native <methods>;
}

# FlexboxLayout — StyleEngine reaches layout params reflectively through the
# AndroidX attribute set, and hosts inflate it from XML.
-keep class com.google.android.flexbox.** { *; }

# WorkManager — VueNativeWorker is instantiated reflectively by
# PeriodicWorkRequestBuilder / OneTimeWorkRequestBuilder in BackgroundTaskModule.
# R8 sees no constructor call, so without these rules a minified host cannot
# construct the Worker and BackgroundTaskModule silently never fires.
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.ListenableWorker
-keep public class * extends androidx.work.Worker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class com.vuenative.core.VueNativeWorker { <init>(...); }

# Vue Native public API — hosts subclass/reference these from Kotlin, Java and
# the merged AndroidManifest, so their names must survive obfuscation.
-keep public class com.vuenative.core.VueNativeActivity { *; }
-keep public class com.vuenative.core.JSRuntime { *; }
-keep public class com.vuenative.core.NativeBridge { *; }
-keep public class com.vuenative.core.NativeModuleRegistry { *; }
-keep public class com.vuenative.core.NativeModule { *; }
-keep public class com.vuenative.core.QRScannerActivity { *; }

# Component factories are resolved by component-type *string* through
# ComponentRegistry, and modules by module-name string, so implementations must
# not be renamed or stripped even though nothing references them statically.
-keep class * implements com.vuenative.core.NativeComponentFactory { *; }
-keep class * implements com.vuenative.core.NativeModule { *; }
-keep interface com.vuenative.core.NativeComponentFactory { *; }
-keep interface com.vuenative.core.NativeModule { *; }

# Biometric / SwipeRefreshLayout — inflated and resolved by name from XML.
-keep class androidx.biometric.** { *; }
-keep class androidx.swiperefreshlayout.** { *; }

# Optional transitive dependencies. Modules are shipped for every platform
# capability, but a host app may exclude some of them (ML Kit, Billing,
# Credential Manager, Play Services); the resulting missing-class warnings must
# not fail the host's minified build.
-dontwarn coil.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**
-dontwarn com.android.billingclient.**
-dontwarn androidx.credentials.**
-dontwarn com.google.android.libraries.identity.googleid.**
-dontwarn com.caverock.androidsvg.**
-dontnote kotlinx.serialization.AnnotationsKt

# Keep annotations and inner classes — several modules read them reflectively.
-keepattributes *Annotation*, InnerClasses, Signature, Exceptions
