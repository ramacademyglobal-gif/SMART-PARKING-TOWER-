# Razorpay checkout uses reflection and annotation-driven callbacks, so its
# classes must survive R8 when a release build enables shrinking.
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepattributes JavascriptInterface
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }
-optimizations !method/inlining/*
-keepclasseswithmembers class * {
  public void onPayment*(...);
}

# CameraX + ML Kit + mobile_scanner — R8 strips these via reflection otherwise,
# causing a null-pointer crash ("getClass() on a null object") in release builds.
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class dev.steenbakker.mobile_scanner.** { *; }
