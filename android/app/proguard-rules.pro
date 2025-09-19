# ===== Flutter =====
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ===== Jitsi Meet SDK =====
-keep class org.jitsi.meet.** { *; }
-keep class org.jitsi.meet.sdk.** { *; }
-keep class org.jitsi.** { *; }
-keep interface org.jitsi.** { *; }

# ===== React Native (Jitsi dependency) =====
-keep class com.facebook.react.** { *; }
-keep class com.facebook.react.bridge.** { *; }
-keep class com.facebook.react.modules.** { *; }
-dontwarn com.facebook.react.**

# ===== WebRTC =====
-keep class org.webrtc.** { *; }
-dontwarn org.chromium.build.BuildHooksAndroid
-dontwarn org.webrtc.**

# ===== Firebase (since you're using it) =====
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ===== General Android =====
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable

