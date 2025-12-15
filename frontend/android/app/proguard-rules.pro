# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep Google Sign-In classes
-keep class com.google.android.gms.** { *; }

# Keep Firebase classes
-keep class com.google.firebase.** { *; }

# Keep OneSignal classes
-keep class com.onesignal.** { *; }

# Keep Qonversion classes
-keep class com.qonversion.android.sdk.** { *; }

# Google Play Core classes (for deferred components - used by Flutter)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Preserve line number information for debugging stack traces
-keepattributes SourceFile,LineNumberTable

# Hide the original source file name
-renamesourcefileattribute SourceFile
