# Consumer ProGuard rules for VueNativeCore library.
# These rules are applied to apps that depend on VueNativeCore.

# J2V8 — V8 engine JNI bindings must not be stripped
-keep class com.eclipsesource.v8.** { *; }
-keepclasseswithmembers class com.eclipsesource.v8.** {
    native <methods>;
}

# Keep Vue Native public API
-keep public class com.vuenative.core.VueNativeActivity { *; }
-keep public class com.vuenative.core.NativeModule { *; }
