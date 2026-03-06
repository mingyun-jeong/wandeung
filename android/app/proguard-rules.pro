## Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

## GeneratedPluginRegistrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

## Keep plugin classes discovered via reflection
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }

## FFmpegKit — JNI 네이티브 메서드가 R8에 의해 제거/난독화되지 않도록 보호
-keep class com.arthenica.ffmpegkit.** { *; }
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-dontwarn com.arthenica.ffmpegkit.**
-dontwarn com.antonkarpenko.ffmpegkit.**

## Play Core (referenced by Flutter deferred components)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
