# Razorpay checkout (razorpay_flutter): keep the SDK and its payment
# callbacks, per https://razorpay.com/docs/payments/payment-gateway/android-integration/standard/
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/
-keepclasseswithmembers class * {
  public void onPayment*(...);
}

# ML Kit barcode scanning (mobile_scanner) looks up its parts by reflection.
# R8 full mode strips them: BarcodeScanning.getClient() then hits a null and
# every QR scan in a release build fails with "genericError" (camera and
# gallery alike). Keep ML Kit and its component registrars.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode_bundled.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }
-dontwarn com.google.mlkit.**
