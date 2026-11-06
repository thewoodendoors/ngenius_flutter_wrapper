import 'package:flutter_test/flutter_test.dart';
import 'package:ngenius_flutter_wrapper/ngenius_flutter_wrapper.dart';

void main() {
  group('NgeniusResult.fromMap', () {
    test('maps every wire status', () {
      const cases = <String, NgeniusStatus>{
        'success': NgeniusStatus.success,
        'authorised': NgeniusStatus.authorised,
        'failed': NgeniusStatus.failed,
        'cancelled': NgeniusStatus.cancelled,
        'invalid': NgeniusStatus.invalid,
        'post_auth_review': NgeniusStatus.postAuthReview,
        'partial': NgeniusStatus.partial,
        'something_new': NgeniusStatus.unknown,
      };
      cases.forEach((wire, status) {
        expect(NgeniusResult.fromMap(<String, Object?>{'status': wire}).status,
            status,
            reason: wire);
      });
      expect(NgeniusResult.fromMap(const <Object?, Object?>{}).status,
          NgeniusStatus.unknown);
    });

    test('keeps the reason and computes paid', () {
      final partial = NgeniusResult.fromMap(<Object?, Object?>{
        'status': 'partial',
        'reason': 'partially_authorised',
      });
      expect(partial.reason, 'partially_authorised');
      expect(partial.paid, isFalse);

      expect(
          NgeniusResult.fromMap(<Object?, Object?>{'status': 'success'}).paid,
          isTrue);
      expect(
          NgeniusResult.fromMap(<Object?, Object?>{'status': 'authorised'})
              .paid,
          isTrue);
      expect(
          NgeniusResult.fromMap(<Object?, Object?>{
            'status': 'failed',
            'reason': null,
          }).reason,
          isNull);
    });

    test('tolerates non-string values and supports equality', () {
      final result =
          NgeniusResult.fromMap(<Object?, Object?>{'status': 7, 'reason': 42});
      expect(result.status, NgeniusStatus.unknown);
      expect(result.reason, '42');
      expect(result,
          const NgeniusResult(status: NgeniusStatus.unknown, reason: '42'));
      expect(result.toString(), 'NgeniusResult(status: unknown, reason: 42)');
    });
  });

  group('argument maps', () {
    test('NgeniusColors sends only the slots that are set', () {
      const colors = NgeniusColors(
        payButtonBackground: 0xFF112233,
        payPageTitle: 0x80445566,
      );
      expect(colors.toMap(), <String, int>{
        'payButtonBackground': 0xFF112233,
        'payPageTitle': 0x80445566,
      });
      expect(const NgeniusColors().toMap(), isEmpty);
    });

    test('NgeniusGooglePay and NgeniusApplePay expose their fields', () {
      expect(
        const NgeniusGooglePay(merchantGatewayId: 'gw-1').toMap(),
        <String, Object?>{'environment': 'TEST', 'merchantGatewayId': 'gw-1'},
      );
      expect(
        const NgeniusApplePay(
          merchantIdentifier: 'merchant.example',
          countryCode: 'AE',
          currencyCode: 'AED',
          merchantName: 'Shop',
          amount: '12.50',
        ).toMap(),
        <String, Object?>{
          'merchantIdentifier': 'merchant.example',
          'countryCode': 'AE',
          'currencyCode': 'AED',
          'merchantName': 'Shop',
          'amount': '12.50',
          'supportedNetworks': <String>['visa', 'masterCard', 'amex'],
        },
      );
    });
  });

  test('NgeniusException describes itself', () {
    const e = NgeniusException(NgeniusException.busy, 'in progress');
    expect(e.toString(), 'NgeniusException(busy): in progress');
    expect(e, isA<Exception>());
  });
}
