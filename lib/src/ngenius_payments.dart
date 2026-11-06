import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'types.dart';

/// Card payments on both platforms, Apple Pay on iOS and Google Pay on Android.
///
/// The `order` maps are the JSON body of the N-Genius "create order" response,
/// decoded with `jsonDecode`. The plugin reads `_links.payment.href` (the pay
/// page) and `_links.payment-authorization.href` (the authorisation endpoint);
/// the iOS SDK also requires the `type` and `action` fields, and Apple Pay needs
/// `_embedded.payment[0]._links.payment:apple_pay`.
class NgeniusPayments {
  NgeniusPayments._();

  /// The channel shared with the native plugins.
  @visibleForTesting
  static const MethodChannel channel = MethodChannel('ngenius_flutter_wrapper');

  /// True on Android and iOS; the native SDKs exist nowhere else.
  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Applies SDK-wide settings; call it before the first payment and again
  /// whenever the app language changes.
  ///
  /// [language] is an ISO 639-1 code (`en`, `ar`, `fr` are what the SDKs ship).
  /// [colors] only affects iOS; `null` restores the SDK defaults.
  static Future<void> configure({
    String language = 'en',
    bool showOrderAmount = true,
    bool showCancelAlert = false,
    NgeniusColors? colors,
  }) async {
    if (!isSupportedPlatform) {
      return;
    }
    await _invoke<void>('configure', <String, Object?>{
      'language': language,
      'showOrderAmount': showOrderAmount,
      'showCancelAlert': showCancelAlert,
      'colors': colors?.toMap(),
    });
  }

  /// Opens the native card payment page for [order] and completes with the
  /// outcome. On Android a [googlePay] config adds a Google Pay button to the
  /// page. [threeDsTimeout] caps one 3-D Secure session.
  ///
  /// Throws [NgeniusException] (`busy`, `no_activity`, `invalid_order`,
  /// `unsupported_platform`, `launch_failed`) when the page cannot be opened.
  static Future<NgeniusResult> payWithCard(
    Map<String, dynamic> order, {
    NgeniusGooglePay? googlePay,
    Duration threeDsTimeout = const Duration(minutes: 5),
  }) async {
    _ensureSupported();
    final map = await _invoke<Map<Object?, Object?>>(
      'payWithCard',
      <String, Object?>{
        'order': order,
        if (googlePay != null) 'googlePay': googlePay.toMap(),
        'threeDsTimeoutMs': threeDsTimeout.inMilliseconds,
      },
    );
    return NgeniusResult.fromMap(map ?? const <Object?, Object?>{});
  }

  /// True when the device can pay with Apple Pay through one of [networks]
  /// (`visa`, `masterCard`, `amex`, `mada`, `discover`, `jcb`). Always false
  /// off iOS.
  static Future<bool> isApplePayAvailable({
    List<String> networks = const <String>['visa', 'masterCard', 'amex'],
  }) async {
    if (!isSupportedPlatform) {
      return false;
    }
    try {
      return await _invoke<bool>(
            'isApplePayAvailable',
            <String, Object?>{'networks': networks},
          ) ??
          false;
    } on NgeniusException {
      return false;
    }
  }

  /// Presents the Apple Pay sheet for [order] and completes with the outcome.
  /// Throws [NgeniusException] like [payWithCard]; `unsupported_platform` on
  /// Android.
  static Future<NgeniusResult> payWithApplePay(
    Map<String, dynamic> order,
    NgeniusApplePay config,
  ) async {
    _ensureSupported();
    final map = await _invoke<Map<Object?, Object?>>(
      'payWithApplePay',
      <String, Object?>{'order': order, 'applePay': config.toMap()},
    );
    return NgeniusResult.fromMap(map ?? const <Object?, Object?>{});
  }

  /// True when Google Pay is ready to pay with a card in [environment]
  /// (`TEST` or `PRODUCTION`). Always false off Android.
  static Future<bool> isGooglePayAvailable({String environment = 'TEST'}) async {
    if (!isSupportedPlatform) {
      return false;
    }
    try {
      return await _invoke<bool>(
            'isGooglePayAvailable',
            <String, Object?>{'environment': environment},
          ) ??
          false;
    } on NgeniusException {
      return false;
    }
  }

  /// Drops a stuck in-flight payment: the pending [payWithCard] /
  /// [payWithApplePay] future completes with [NgeniusStatus.unknown] and
  /// reason `reset`, and a new payment may be started.
  static Future<void> reset() async {
    if (!isSupportedPlatform) {
      return;
    }
    await _invoke<void>('reset');
  }

  static void _ensureSupported() {
    if (!isSupportedPlatform) {
      throw const NgeniusException(
        NgeniusException.unsupportedPlatform,
        'N-Genius payments are only available on Android and iOS.',
      );
    }
  }

  static Future<T?> _invoke<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw NgeniusException(
        e.code,
        e.message ?? 'The native N-Genius plugin reported "${e.code}".',
      );
    } on MissingPluginException catch (e) {
      throw NgeniusException(
        NgeniusException.unsupportedPlatform,
        e.message ??
            'The native N-Genius plugin is not part of this build; rebuild the app.',
      );
    }
  }
}
