## 0.2.1

* Android: `PayReturnActivity` no longer shows the return link to the other SDKs in the app. An
  analytics or attribution SDK that watches every activity (AppsFlyer does) read the link from the
  activity's intent and reported it as a deep link, with whatever the merchant's return page had
  put into it. The activity now swaps its intent for an empty one before `super.onCreate()`, which
  is where those SDKs are told about it. The way back itself is unchanged; no Dart or iOS change.

## 0.2.0

* Android: `PayReturnActivity`, the way back into the app from N-Genius's hosted payment page shown
  in a Custom Tab (the card step for Multi-Currency Pricing, which the mobile SDKs cannot do). The
  plugin's manifest merges it with an intent filter for the scheme `<applicationId>.pay`; a link to
  `<applicationId>.pay://return` on the merchant's return page brings the running app back to the
  front and closes the tab. No Dart API change; see "The card step on N-Genius's hosted payment
  page" in the README.
* The version is the same in `pubspec.yaml`, the Gradle file and the podspec again.

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
