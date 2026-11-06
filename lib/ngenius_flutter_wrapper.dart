/// Card, Apple Pay (iOS) and Google Pay (Android) payments through the official
/// N-Genius Online (Network International) native payment SDKs.
///
/// Create the order on your backend with the N-Genius API, hand the order JSON
/// to [NgeniusPayments.payWithCard] or [NgeniusPayments.payWithApplePay], and
/// read the outcome from the returned [NgeniusResult].
library;

export 'src/apple_pay_button.dart';
export 'src/ngenius_payments.dart';
export 'src/types.dart';
