# Consumer rules: applied automatically to apps that minify with R8.

# The N-Genius SDK deserialises gateway responses with Gson and parcels its results.
-keep class payment.sdk.android.** { *; }

# Google Pay (play-services-wallet) request/response classes.
-keep class com.google.android.gms.wallet.** { *; }

-dontwarn com.nimbusds.**
# payment-sdk links its Samsung Pay module; the Samsung SDK itself is only needed for Samsung Pay.
-dontwarn com.samsung.android.sdk.samsungpay.**
