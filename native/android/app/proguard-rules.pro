# App-level ProGuard rules for Vue Native example app.
# VueNativeCore consumer rules are applied automatically via the library.

# Keep MainActivity so it can be launched by the Android system
-keep class com.vuenative.example.counter.MainActivity { *; }
