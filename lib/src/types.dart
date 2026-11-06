/// Outcome of a payment attempt, normalised across the iOS and Android SDKs.
enum NgeniusStatus {
  /// The payment was captured (`SALE` / `PURCHASE` orders).
  success,

  /// The payment was authorised but not captured (`AUTH` orders).
  authorised,

  /// The gateway or the SDK rejected the payment, or a network error occurred.
  failed,

  /// The customer closed the payment page without paying.
  cancelled,

  /// The order handed to the SDK was not usable (iOS `InValidRequest`).
  invalid,

  /// The payment is held for a post-authorisation fraud review.
  postAuthReview,

  /// A partial-authorisation outcome; [NgeniusResult.reason] names the case.
  partial,

  /// A status this version of the plugin does not know.
  unknown;

  /// Parses the value sent by the native side (`success`, `post_auth_review`, ...).
  static NgeniusStatus fromWire(String? value) {
    return switch (value) {
      'success' => NgeniusStatus.success,
      'authorised' => NgeniusStatus.authorised,
      'failed' => NgeniusStatus.failed,
      'cancelled' => NgeniusStatus.cancelled,
      'invalid' => NgeniusStatus.invalid,
      'post_auth_review' => NgeniusStatus.postAuthReview,
      'partial' => NgeniusStatus.partial,
      _ => NgeniusStatus.unknown,
    };
  }
}

/// Result of [NgeniusPayments.payWithCard] or [NgeniusPayments.payWithApplePay].
class NgeniusResult {
  const NgeniusResult({required this.status, this.reason});

  /// Builds a result from the `{status, reason}` map the native plugins send.
  factory NgeniusResult.fromMap(Map<dynamic, dynamic> map) {
    final Object? reason = map['reason'];
    return NgeniusResult(
      status: NgeniusStatus.fromWire(map['status']?.toString()),
      reason: reason?.toString(),
    );
  }

  final NgeniusStatus status;

  /// Extra detail when the SDK gives one: the Android failure message, the
  /// partial-authorisation case (`partially_authorised`,
  /// `partial_auth_declined`, `partial_auth_decline_failed`) or
  /// `authorization_failed` when the gateway refused the SDK's access token.
  final String? reason;

  /// True when money was captured or authorised.
  bool get paid =>
      status == NgeniusStatus.success || status == NgeniusStatus.authorised;

  @override
  bool operator ==(Object other) =>
      other is NgeniusResult && other.status == status && other.reason == reason;

  @override
  int get hashCode => Object.hash(status, reason);

  @override
  String toString() => 'NgeniusResult(status: ${status.name}, reason: $reason)';
}

/// Google Pay settings for [NgeniusPayments.payWithCard] on Android.
class NgeniusGooglePay {
  const NgeniusGooglePay({
    required this.merchantGatewayId,
    this.environment = 'TEST',
  });

  /// `'TEST'` or `'PRODUCTION'` (the Google Pay API environment).
  final String environment;

  /// The gateway merchant id N-Genius issues for Google Pay.
  final String merchantGatewayId;

  Map<String, Object?> toMap() => <String, Object?>{
        'environment': environment,
        'merchantGatewayId': merchantGatewayId,
      };
}

/// Apple Pay settings for [NgeniusPayments.payWithApplePay] on iOS.
class NgeniusApplePay {
  const NgeniusApplePay({
    required this.merchantIdentifier,
    required this.countryCode,
    required this.currencyCode,
    required this.merchantName,
    required this.amount,
    this.supportedNetworks = const <String>['visa', 'masterCard', 'amex'],
  });

  /// The Apple merchant identifier (`merchant.com.example.shop`) enabled in the
  /// app's Apple Pay entitlement.
  final String merchantIdentifier;

  /// ISO 3166 country code, for example `AE`.
  final String countryCode;

  /// ISO 4217 currency code, for example `AED`; should match the order.
  final String currencyCode;

  /// Label of the single payment summary line shown on the Apple Pay sheet.
  final String merchantName;

  /// Amount as decimal text (`'12.50'`), in major units of [currencyCode].
  final String amount;

  /// Any of `visa`, `masterCard`, `amex`, `mada`, `discover`, `jcb`.
  final List<String> supportedNetworks;

  Map<String, Object?> toMap() => <String, Object?>{
        'merchantIdentifier': merchantIdentifier,
        'countryCode': countryCode,
        'currencyCode': currencyCode,
        'merchantName': merchantName,
        'amount': amount,
        'supportedNetworks': supportedNetworks,
      };
}

/// Colours of the iOS payment page (`NISdkColors`), as ARGB ints such as
/// `0xFF1E88E5` or `Colors.blue.toARGB32()`. Unset slots keep the SDK default.
/// Android takes its colours from `payment_sdk_*` resources in the app instead.
class NgeniusColors {
  const NgeniusColors({
    this.payButtonBackground,
    this.payButtonTitle,
    this.navigationBar,
    this.navigationBarButton,
    this.cardPreviewStart,
    this.cardPreviewCenter,
    this.cardPreviewEnd,
    this.progressLoader,
    this.payPageBackground,
    this.payPageLabel,
    this.textFieldLabel,
    this.payPageTitle,
  });

  final int? payButtonBackground;
  final int? payButtonTitle;
  final int? navigationBar;
  final int? navigationBarButton;
  final int? cardPreviewStart;
  final int? cardPreviewCenter;
  final int? cardPreviewEnd;
  final int? progressLoader;
  final int? payPageBackground;
  final int? payPageLabel;
  final int? textFieldLabel;
  final int? payPageTitle;

  /// Only the slots that are set.
  Map<String, int> toMap() {
    final map = <String, int>{};
    void put(String key, int? value) {
      if (value != null) {
        map[key] = value;
      }
    }

    put('payButtonBackground', payButtonBackground);
    put('payButtonTitle', payButtonTitle);
    put('navigationBar', navigationBar);
    put('navigationBarButton', navigationBarButton);
    put('cardPreviewStart', cardPreviewStart);
    put('cardPreviewCenter', cardPreviewCenter);
    put('cardPreviewEnd', cardPreviewEnd);
    put('progressLoader', progressLoader);
    put('payPageBackground', payPageBackground);
    put('payPageLabel', payPageLabel);
    put('textFieldLabel', textFieldLabel);
    put('payPageTitle', payPageTitle);
    return map;
  }
}

/// Thrown when a payment cannot be started; [code] is one of the constants
/// below (or a code reported by the native plugin).
class NgeniusException implements Exception {
  const NgeniusException(this.code, this.message);

  /// Another payment is still in progress.
  static const String busy = 'busy';

  /// No activity / view controller to present the payment page from.
  static const String noActivity = 'no_activity';

  /// The order map lacks the links or fields the SDK needs.
  static const String invalidOrder = 'invalid_order';

  /// Not Android or iOS, or the native plugin is missing from the build.
  static const String unsupportedPlatform = 'unsupported_platform';

  /// The SDK refused to open its payment page.
  static const String launchFailed = 'launch_failed';

  final String code;
  final String message;

  @override
  String toString() => 'NgeniusException($code): $message';
}
