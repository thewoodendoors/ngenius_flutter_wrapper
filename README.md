# ngenius_flutter_wrapper

Card payments, Apple Pay (iOS) and Google Pay (Android) inside a Flutter app, through the official
N-Genius Online (Network International) native payment SDKs. The plugin contains nothing specific to
any app: no keys, no endpoints, no texts beyond generic error messages. Your backend creates the order
with the N-Genius API; the app hands the order JSON to the plugin and gets a result back.

| Platform | Native SDK | Pinned version | Source |
| --- | --- | --- | --- |
| iOS 15+ | [payment-sdk-ios](https://github.com/network-international/payment-sdk-ios), pod `NISdk` | 6.1.6 | CocoaPods trunk |
| Android 5.0+ (API 21) | [payment-sdk-android](https://github.com/network-international/payment-sdk-android), `payment-sdk` + `payment-sdk-core` | 5.2.7 | JitPack |

6.1.6 is the newest NISdk on the CocoaPods trunk (7.x only exists as GitHub tags) and 5.2.7 is the
newest Android tag that builds green on JitPack (every 7.x build fails there).

## Install

```yaml
dependencies:
  ngenius_flutter_wrapper:
    path: ../ngenius_flutter_wrapper   # or a git dependency
```

### Android

* **JitPack** is registered by the plugin itself (`rootProject.allprojects { repositories { maven("https://jitpack.io") } }`
  in `android/build.gradle.kts`), so a standard Flutter `settings.gradle` needs nothing. If your
  `settings.gradle` uses `dependencyResolutionManagement` with `FAIL_ON_PROJECT_REPOS`, add
  `maven { url = uri("https://jitpack.io") }` there instead.
* The host activity may stay a plain `FlutterActivity`. `FlutterActivity` extends `android.app.Activity`,
  so the SDK's `PaymentsLauncher` (which needs `ComponentActivity.registerForActivityResult`) cannot be
  used there; the plugin then starts the SDK's `PaymentsActivity` with `startActivityForResult`
  (request code `0x4E47`) and reads the same `PaymentsResult`. A `FlutterFragmentActivity` host gets
  the `PaymentsLauncher` path automatically.
* **Google Pay** needs the `merchantGatewayId` (the merchant ID of your Google Pay & Wallet Console
  business profile; the SDK sends it to Google as the merchant id and as the gateway merchant id of
  the `networkintl` gateway), Google Pay enabled on your outlet by Network International, and the
  Google Pay API meta-data, which the plugin's manifest merges into the app. Test cards work in the
  `TEST` environment without onboarding; `PRODUCTION` needs Google's approval of your app.
* **Arabic**: set `android:supportsRtl="true"` on `<application>` so the SDK's screens mirror.
* **Colours** are Android resources. Override any of the SDK's `payment_sdk_*` colours in your app's
  `res/values/colors.xml` (and `values-night/`): `payment_sdk_toolbar_color`,
  `payment_sdk_toolbar_text_color`, `payment_sdk_toolbar_icon_color`,
  `payment_sdk_pay_button_background_color`, `payment_sdk_pay_button_text_color`,
  `payment_sdk_pay_button_disabled_background_color`, `payment_sdk_pay_button_disabled_text_color`,
  `payment_sdk_card_start_color`, `payment_sdk_card_center_color`, `payment_sdk_card_end_color`,
  `payment_sdk_card_text_color`, `payment_sdk_page_background_color`, `payment_sdk_floating_hint_color`,
  `payment_sdk_text_field_text_color`, `payment_sdk_text_field_placeholder_color`,
  `payment_sdk_divider_color`, `payment_sdk_progress_loader_color`.
* R8 keep rules for `payment.sdk.android.**` and `com.google.android.gms.wallet.**` ship as consumer
  rules; nothing to add to your `proguard-rules.pro`.
* The SDK brings Jetpack Compose 1.7, AppCompat, Material and `play-services-wallet` 19.4.0 as runtime
  dependencies.

### iOS

* `platform :ios, '15.0'` in the Podfile (NISdk's minimum). The plugin is CocoaPods-only because NISdk has
  no Swift package; Flutter's Swift Package Manager mode falls back to CocoaPods for it, so keep a Podfile.
  `use_frameworks! :linkage => :static` is fine (the SDK's resource bundle is found through the main bundle).
* **Apple Pay**: add the Apple Pay capability in Xcode (Signing & Capabilities) with your merchant
  identifier, create the merchant ID and the payment processing certificate in the Apple developer portal,
  and upload the certificate to the N-Genius portal. Test on a device with a sandbox tester account
  (App Store Connect > Users and Access > Sandbox Testers) and Apple's test cards. The order must have
  Apple Pay enabled on the outlet: the plugin checks `_embedded.payment[0]._links.payment:apple_pay`.
* The `NgeniusApplePayButton` is the real `PKPaymentButton` (Apple requires its artwork).
* Colours: `NgeniusPayments.configure(colors: NgeniusColors(...))`.

## Usage

```dart
import 'package:ngenius_flutter_wrapper/ngenius_flutter_wrapper.dart';

// Once, and again when the app language changes.
await NgeniusPayments.configure(language: 'ar', showOrderAmount: true, showCancelAlert: false);

// `order` is the JSON body of the N-Genius create-order response, decoded with jsonDecode.
final Map<String, dynamic> order = await myBackend.createOrder();

final NgeniusResult result = await NgeniusPayments.payWithCard(
  order,
  googlePay: const NgeniusGooglePay(merchantGatewayId: 'your-gateway-merchant-id', environment: 'TEST'),
  threeDsTimeout: const Duration(minutes: 5),
);
if (result.paid) {
  // Confirm with your backend (GET the order) before fulfilling.
}
```

Apple Pay:

```dart
if (await NgeniusPayments.isApplePayAvailable()) {
  NgeniusApplePayButton(
    type: 'buy',
    style: 'black',
    onPressed: () async {
      final result = await NgeniusPayments.payWithApplePay(
        order,
        const NgeniusApplePay(
          merchantIdentifier: 'merchant.com.example.shop',
          countryCode: 'AE',
          currencyCode: 'AED',
          merchantName: 'Example shop',
          amount: '12.50', // major units as decimal text
          supportedNetworks: ['visa', 'masterCard', 'amex', 'mada'],
        ),
      );
    },
  );
}
```

### API

| Member | Notes |
| --- | --- |
| `NgeniusPayments.configure({language, showOrderAmount, showCancelAlert, colors})` | `language` is ISO 639-1 (`en`, `ar`, `fr` ship with the SDKs); `colors` is iOS only, `null` restores the defaults. |
| `NgeniusPayments.payWithCard(order, {googlePay, threeDsTimeout})` | Opens the native card page. `googlePay` adds a Google Pay button on Android; ignored on iOS. |
| `NgeniusPayments.isApplePayAvailable({networks})` | `NISdk.deviceSupportsApplePay()` and `PKPaymentAuthorizationController.canMakePayments(usingNetworks:)`; false elsewhere. |
| `NgeniusPayments.payWithApplePay(order, config)` | Presents the Apple Pay sheet through the SDK; `unsupported_platform` on Android. |
| `NgeniusPayments.isGooglePayAvailable({environment})` | `isReadyToPay` for CARD / PAN_ONLY + CRYPTOGRAM_3DS / VISA + MASTERCARD in `TEST` or `PRODUCTION`; false elsewhere. |
| `NgeniusPayments.reset()` | Completes a stuck in-flight payment with `unknown` / `reset` so a new one can start. |
| `NgeniusApplePayButton({onPressed, type, style, height, cornerRadius})` | `UiKitView` of a `PKPaymentButton`; `SizedBox.shrink()` off iOS. |

`NgeniusResult` has `status` (`NgeniusStatus`), `reason` and `paid` (`success` or `authorised`).

### Result mapping

| `NgeniusStatus` | iOS `PaymentStatus` | Android `PaymentsResult` | `reason` |
| --- | --- | --- | --- |
| `success` | `PaymentSuccess` | `Success` | |
| `authorised` | (iOS reports AUTH orders as `PaymentSuccess`) | `Authorised` | |
| `failed` | `PaymentFailed`, or `AuthorizationStatus.AuthFailed` | `Failed(error)` | the SDK's message; `authorization_failed`; `no_result`; `activity_detached` |
| `cancelled` | `PaymentCancelled` | `Cancelled` | |
| `invalid` | `InValidRequest` | | |
| `postAuthReview` | `PaymentPostAuthReview` | `PostAuthReview` | |
| `partial` | `PartiallyAuthorised`, `PartialAuthDeclined`, `PartialAuthDeclineFailed` | same names | `partially_authorised`, `partial_auth_declined`, `partial_auth_decline_failed` |
| `unknown` | anything else | anything else | `reset` after `NgeniusPayments.reset()` |

The first terminal status wins; later callbacks for the same attempt are ignored.

### Errors

`payWithCard` and `payWithApplePay` throw `NgeniusException(code, message)`:

| code | meaning |
| --- | --- |
| `busy` | another payment is in progress |
| `no_activity` | no activity / view controller to present from |
| `invalid_order` | the order lacks `_links.payment.href`, `_links.payment-authorization.href`, (iOS) `type` / `action`, or (Apple Pay) `payment:apple_pay` |
| `unsupported_platform` | web or desktop (thrown before the channel is touched), or the native plugin is missing from the build |
| `launch_failed` | the SDK refused to open, or the Apple Pay config is incomplete |

### The order

Pass the create-order response as is. Both SDKs read the order-level links:

```json
{
  "type": "SINGLE",
  "action": "SALE",
  "amount": { "currencyCode": "AED", "value": 1250 },
  "_links": {
    "payment": { "href": "https://paypage.sandbox.ngenius-payments.com/?code=..." },
    "payment-authorization": { "href": "https://api-gateway.sandbox.ngenius-payments.com/transactions/paymentAuthorization" }
  },
  "_embedded": { "payment": [ { "_links": { "payment:apple_pay": { "href": "..." } } } ] }
}
```

`tool/sandbox_order.py` creates one on the sandbox from `NGENIUS_API_KEY` and `NGENIUS_OUTLET_REF`
in the environment (standard library only):

```
python tool/sandbox_order.py --action SALE --amount 1250 --currency AED --language en --email buyer@example.com
```

## Example app

`example/` pastes an order (or loads it with `--dart-define=ORDER_JSON_FILE=<device path>`), toggles
English / Arabic, pays with card (with Google Pay when `merchantGatewayId` and the environment are filled
in), shows the `NgeniusApplePayButton` when Apple Pay is available, and prints the result. No backend calls.

## Limits

* No saved cards, no Samsung Pay, no Aani; the SDKs' Visa instalment and partial-authorisation screens
  run inside the native page and surface through the statuses above.
* Android colours cannot be set from Dart (resources only).
* Web and desktop throw `unsupported_platform`.
* Always confirm the order state with your backend before fulfilling; the result is a client-side signal.

## Unverified on iOS until the first Mac build

Every Swift symbol was checked against the NISdk v6.1.6 sources (`NISdk.swift`,
`CardPaymentDelegate.swift`, `ApplePayDelegate.swift`, `NISdkColors.swift`, `OrderResponse.swift`,
`OrderLinks.swift`, `PaymentLinks.swift`, `EmbeddedData.swift`, `CardProvider.swift`,
`PaymentViewController.swift`, `NISdk.podspec`), but no Swift compiler ran on this plugin yet:

* `ios/Classes/*.swift` compiling against the current Xcode (Flutter, PassKit and NISdk module imports).
* `PKMerchantCapability(rawValue:)` composition of 3-D Secure / credit / debit (chosen because Apple
  renamed the Swift cases in the iOS 17 SDK).
* The `@objc` inference for `authorizationDidComplete(with:)`, an optional requirement of the `@objc`
  `CardPaymentDelegate` protocol.
* `pod install` resolving `NISdk 6.1.6` next to Flutter with static linkage, and the SDK's resource
  bundle (fonts, localisations) being found at runtime.
* The `UiKitView` button, its per-view channel and `PKPaymentButton.cornerRadius`.
* `UIWindowScene.keyWindow` based top-view-controller lookup in a scene-based Flutter app.
