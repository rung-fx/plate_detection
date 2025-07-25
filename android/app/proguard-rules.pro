# TensorFlow Lite keep rules
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# TensorFlow Lite GPU Delegate
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.gpu.**

# Flutter Tesseract OCR
-keep class com.googlecode.tesseract.android.** { *; }
-dontwarn com.googlecode.tesseract.android.**

# Prevent R8 from stripping native methods
-keepclasseswithmembernames class * {
    native <methods>;
}