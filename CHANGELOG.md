## 0.1.1

* Android: the SDK's card screen (`PaymentsActivity`) is declared without a theme and
  inherited the host app's, which in a Flutter app is not an AppCompat theme; the screen
  died in `onCreate` with "You need to use a Theme.AppCompat theme". The plugin's manifest
  now gives it `Theme.NgeniusFlutterWrapper.Payments` (an AppCompat DayNight theme).

## 0.1.0

* Initial release.
* Card payments on Android (payment-sdk 5.2.7 via JitPack) and iOS (NISdk 6.1.6 via CocoaPods).
* Google Pay on Android (`NgeniusGooglePay`), Apple Pay on iOS (`NgeniusApplePay`, `NgeniusApplePayButton`).
* `NgeniusPayments.configure` for language, order amount, cancel alert and iOS colours.
* `tool/sandbox_order.py` to create sandbox orders for testing.
