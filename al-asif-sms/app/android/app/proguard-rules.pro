# Keep Flutter plugin classes that are accessed by name via JNI/reflection.
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keepclassmembers class io.flutter.plugins.** { *; }
-keep class kotlin.coroutines.Continuation { *; }
-dontwarn io.flutter.plugins.**
