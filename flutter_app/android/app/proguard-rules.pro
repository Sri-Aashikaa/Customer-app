# Flutter SharedPreferences Proguard Keep Rules
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep interface io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class * implements io.flutter.plugin.common.PluginRegistry$PluginRegistrantCallback { *; }

# Flutter Play Core Deferred Components
-dontwarn com.google.android.play.core.**

# Security & Serialization Rules for Release Builds
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
