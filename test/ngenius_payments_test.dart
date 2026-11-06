import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngenius_flutter_wrapper/ngenius_flutter_wrapper.dart';

TestDefaultBinaryMessenger get messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> log = <MethodCall>[];
  Object? Function(MethodCall call)? responder;

  setUp(() {
    log.clear();
    responder = null;
    messenger.setMockMethodCallHandler(NgeniusPayments.channel,
        (MethodCall call) async {
      log.add(call);
      return responder?.call(call);
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(NgeniusPayments.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  const Map<String, dynamic> order = <String, dynamic>{
    'type': 'SINGLE',
    'action': 'SALE',
    'amount': <String, Object?>{'currencyCode': 'AED', 'value': 1250},
    '_links': <String, Object?>{
      'payment': <String, Object?>{
        'href': 'https://paypage.sandbox.ngenius-payments.com/?code=abc',
      },
      'payment-authorization': <String, Object?>{
        'href':
            'https://api-gateway.sandbox.ngenius-payments.com/transactions/paymentAuthorization',
      },
    },
    '_embedded': <String, Object?>{
      'payment': <Object?>[
        <String, Object?>{
          '_links': <String, Object?>{
            'payment:apple_pay': <String, Object?>{
              'href': 'https://example.invalid/apple-pay',
            },
          },
        },
      ],
    },
  };

  test('configure sends the language, the flags and only the set colours',
      () async {
    await NgeniusPayments.configure(
      language: 'ar',
      showOrderAmount: false,
      showCancelAlert: true,
      colors: const NgeniusColors(
        payButtonBackground: 0xFF112233,
        navigationBar: 0xFF445566,
      ),
    );
    expect(log, hasLength(1));
    expect(log.single.method, 'configure');
    expect(log.single.arguments, <String, Object?>{
      'language': 'ar',
      'showOrderAmount': false,
      'showCancelAlert': true,
      'colors': <String, Object?>{
        'payButtonBackground': 0xFF112233,
        'navigationBar': 0xFF445566,
      },
    });
  });

  test('configure defaults send null colours', () async {
    await NgeniusPayments.configure();
    expect(log.single.arguments, <String, Object?>{
      'language': 'en',
      'showOrderAmount': true,
      'showCancelAlert': false,
      'colors': null,
    });
  });

  test('payWithCard sends the order, the Google Pay config and the timeout',
      () async {
    responder = (_) => <String, Object?>{'status': 'success', 'reason': null};
    final result = await NgeniusPayments.payWithCard(
      order,
      googlePay: const NgeniusGooglePay(
        merchantGatewayId: 'gw-1',
        environment: 'PRODUCTION',
      ),
      threeDsTimeout: const Duration(minutes: 2),
    );
    expect(log.single.method, 'payWithCard');
    expect(log.single.arguments, <String, Object?>{
      'order': order,
      'googlePay': <String, Object?>{
        'environment': 'PRODUCTION',
        'merchantGatewayId': 'gw-1',
      },
      'threeDsTimeoutMs': 120000,
    });
    expect(result.status, NgeniusStatus.success);
    expect(result.paid, isTrue);
  });

  test('payWithCard without Google Pay omits the key and defaults to 5 min',
      () async {
    responder = (_) => <String, Object?>{'status': 'cancelled'};
    final result = await NgeniusPayments.payWithCard(order);
    expect(log.single.arguments, <String, Object?>{
      'order': order,
      'threeDsTimeoutMs': 300000,
    });
    expect(result.status, NgeniusStatus.cancelled);
    expect(result.reason, isNull);
  });

  test('payWithCard turns a PlatformException into an NgeniusException',
      () async {
    responder = (_) => throw PlatformException(
          code: 'invalid_order',
          message: 'missing links',
        );
    await expectLater(
      NgeniusPayments.payWithCard(const <String, dynamic>{}),
      throwsA(isA<NgeniusException>()
          .having((e) => e.code, 'code', NgeniusException.invalidOrder)
          .having((e) => e.message, 'message', 'missing links')),
    );
  });

  test('payWithApplePay sends the order and the Apple Pay config', () async {
    responder = (_) => <String, Object?>{
          'status': 'partial',
          'reason': 'partially_authorised',
        };
    final result = await NgeniusPayments.payWithApplePay(
      order,
      const NgeniusApplePay(
        merchantIdentifier: 'merchant.example',
        countryCode: 'AE',
        currencyCode: 'AED',
        merchantName: 'Shop',
        amount: '12.50',
        supportedNetworks: <String>['visa', 'mada'],
      ),
    );
    expect(log.single.method, 'payWithApplePay');
    expect(log.single.arguments, <String, Object?>{
      'order': order,
      'applePay': <String, Object?>{
        'merchantIdentifier': 'merchant.example',
        'countryCode': 'AE',
        'currencyCode': 'AED',
        'merchantName': 'Shop',
        'amount': '12.50',
        'supportedNetworks': <String>['visa', 'mada'],
      },
    });
    expect(result.status, NgeniusStatus.partial);
    expect(result.reason, 'partially_authorised');
  });

  test('isApplePayAvailable passes the networks and returns the native answer',
      () async {
    responder = (_) => true;
    expect(
        await NgeniusPayments.isApplePayAvailable(networks: const <String>['visa']),
        isTrue);
    expect(log.single.method, 'isApplePayAvailable');
    expect(log.single.arguments, <String, Object?>{
      'networks': <String>['visa'],
    });
  });

  test('isGooglePayAvailable passes the environment', () async {
    responder = (_) => false;
    expect(
        await NgeniusPayments.isGooglePayAvailable(environment: 'PRODUCTION'),
        isFalse);
    expect(log.single.method, 'isGooglePayAvailable');
    expect(log.single.arguments, <String, Object?>{
      'environment': 'PRODUCTION',
    });
  });

  test('availability checks are false when the native side is missing',
      () async {
    messenger.setMockMethodCallHandler(NgeniusPayments.channel, null);
    expect(await NgeniusPayments.isApplePayAvailable(), isFalse);
    expect(await NgeniusPayments.isGooglePayAvailable(), isFalse);
  });

  test('reset sends reset', () async {
    await NgeniusPayments.reset();
    expect(log.single.method, 'reset');
    expect(log.single.arguments, isNull);
  });

  group('off the mobile platforms', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    });

    test('payWithCard throws unsupported_platform without touching the channel',
        () async {
      await expectLater(
        NgeniusPayments.payWithCard(order),
        throwsA(isA<NgeniusException>().having(
            (e) => e.code, 'code', NgeniusException.unsupportedPlatform)),
      );
      expect(log, isEmpty);
    });

    test('payWithApplePay throws unsupported_platform', () async {
      await expectLater(
        NgeniusPayments.payWithApplePay(
          order,
          const NgeniusApplePay(
            merchantIdentifier: 'merchant.example',
            countryCode: 'AE',
            currencyCode: 'AED',
            merchantName: 'Shop',
            amount: '1.00',
          ),
        ),
        throwsA(isA<NgeniusException>().having(
            (e) => e.code, 'code', NgeniusException.unsupportedPlatform)),
      );
      expect(log, isEmpty);
    });

    test('availability is false and configure / reset are no-ops', () async {
      expect(await NgeniusPayments.isApplePayAvailable(), isFalse);
      expect(await NgeniusPayments.isGooglePayAvailable(), isFalse);
      await NgeniusPayments.configure();
      await NgeniusPayments.reset();
      expect(log, isEmpty);
    });
  });
}
