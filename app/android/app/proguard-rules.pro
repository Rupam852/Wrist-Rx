# Flutter proguard rules
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase / Google Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Keep app's main classes
-keep class com.wristrx.app.** { *; }

# Keep Dart entry points
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }

# Suppress warnings for known safe classes
-dontwarn okhttp3.**
-dontwarn okio.**
