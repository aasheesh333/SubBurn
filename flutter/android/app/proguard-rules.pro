# Flutter + plugin keep rules.

-keep class io.flutter.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.onesignal.** { *; }

-dontwarn com.google.firebase.**
-dontwarn com.onesignal.**

# Flutter's engine references Play Core's split-install classes even when the
# app does not depend on Play Core, so R8 reports them as missing and aborts.
# The app is not installed as a Play feature split, so the classes are genuinely
# absent and safe to ignore.
-dontwarn com.google.android.play.core.**
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
