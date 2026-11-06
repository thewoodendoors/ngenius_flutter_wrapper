import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ngenius_flutter_wrapper/ngenius_flutter_wrapper.dart';

/// Optional: `flutter run --dart-define=ORDER_JSON_FILE=/data/local/tmp/order.json`
/// pre-fills the order field from a file on the device.
const String orderJsonFile = String.fromEnvironment('ORDER_JSON_FILE');

void main() {
  runApp(const NgeniusExampleApp());
}

class NgeniusExampleApp extends StatelessWidget {
  const NgeniusExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'N-Genius example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const PaymentPage(),
    );
  }
}

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final TextEditingController _order = TextEditingController();
  final TextEditingController _merchantGatewayId = TextEditingController();
  final TextEditingController _googlePayEnvironment =
      TextEditingController(text: 'TEST');
  final TextEditingController _applePayMerchantId = TextEditingController();
  final TextEditingController _applePayCountry =
      TextEditingController(text: 'AE');
  final TextEditingController _applePayMerchantName =
      TextEditingController(text: 'Example shop');

  String _language = 'en';
  bool _applePayAvailable = false;
  bool? _googlePayAvailable;
  bool _busy = false;
  String _result = 'No payment yet.';

  @override
  void initState() {
    super.initState();
    _loadOrderFile();
    _configure();
    _checkWallets();
  }

  @override
  void dispose() {
    _order.dispose();
    _merchantGatewayId.dispose();
    _googlePayEnvironment.dispose();
    _applePayMerchantId.dispose();
    _applePayCountry.dispose();
    _applePayMerchantName.dispose();
    super.dispose();
  }

  Future<void> _loadOrderFile() async {
    if (orderJsonFile.isEmpty || kIsWeb) {
      return;
    }
    try {
      final text = await File(orderJsonFile).readAsString();
      if (mounted) {
        setState(() => _order.text = text);
      }
    } on IOException catch (e) {
      _show('Could not read $orderJsonFile: $e');
    }
  }

  Future<void> _configure() async {
    try {
      await NgeniusPayments.configure(
        language: _language,
        showOrderAmount: true,
        showCancelAlert: false,
      );
    } on NgeniusException catch (e) {
      _show(e.toString());
    }
  }

  Future<void> _checkWallets() async {
    final applePay = await NgeniusPayments.isApplePayAvailable();
    bool? googlePay;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      googlePay = await NgeniusPayments.isGooglePayAvailable(
        environment: _googlePayEnvironmentValue,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _applePayAvailable = applePay;
      _googlePayAvailable = googlePay;
    });
  }

  String get _googlePayEnvironmentValue {
    final value = _googlePayEnvironment.text.trim().toUpperCase();
    return value.isEmpty ? 'TEST' : value;
  }

  Map<String, dynamic>? _parseOrder() {
    try {
      final decoded = jsonDecode(_order.text);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      _show('The order must be a JSON object.');
    } on FormatException catch (e) {
      _show('Invalid order JSON: ${e.message}');
    }
    return null;
  }

  Future<void> _payWithCard() async {
    final order = _parseOrder();
    if (order == null) {
      return;
    }
    final merchantGatewayId = _merchantGatewayId.text.trim();
    final googlePay = merchantGatewayId.isEmpty
        ? null
        : NgeniusGooglePay(
            merchantGatewayId: merchantGatewayId,
            environment: _googlePayEnvironmentValue,
          );
    await _run(() => NgeniusPayments.payWithCard(order, googlePay: googlePay));
  }

  Future<void> _payWithApplePay() async {
    final order = _parseOrder();
    if (order == null) {
      return;
    }
    final amount = order['amount'];
    final currency = amount is Map ? amount['currencyCode']?.toString() : null;
    final minorUnits = amount is Map ? amount['value'] : null;
    if (currency == null || minorUnits is! num) {
      _show('The order has no amount.currencyCode / amount.value.');
      return;
    }
    final config = NgeniusApplePay(
      merchantIdentifier: _applePayMerchantId.text.trim(),
      countryCode: _applePayCountry.text.trim(),
      currencyCode: currency,
      merchantName: _applePayMerchantName.text.trim(),
      amount: minorUnitsToDecimal(minorUnits, currency),
    );
    await _run(() => NgeniusPayments.payWithApplePay(order, config));
  }

  Future<void> _run(Future<NgeniusResult> Function() pay) async {
    setState(() {
      _busy = true;
      _result = 'Waiting for the payment page...';
    });
    try {
      final result = await pay();
      final reason = result.reason == null ? '' : ' (${result.reason})';
      _setResult('${result.status.name}$reason${result.paid ? ' - paid' : ''}');
    } on NgeniusException catch (e) {
      _setResult('Error ${e.code}: ${e.message}');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _setResult(String text) {
    if (mounted) {
      setState(() => _result = text);
    }
  }

  void _show(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('N-Genius example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(
            controller: _order,
            minLines: 4,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Order JSON (create-order response)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(value: 'en', label: Text('English')),
              ButtonSegment<String>(value: 'ar', label: Text('Arabic')),
            ],
            selected: <String>{_language},
            onSelectionChanged: (Set<String> selection) {
              setState(() => _language = selection.first);
              _configure();
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _merchantGatewayId,
                  decoration: const InputDecoration(
                    labelText: 'Google Pay merchantGatewayId',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _googlePayEnvironment,
                  decoration: const InputDecoration(
                    labelText: 'TEST / PRODUCTION',
                  ),
                ),
              ),
            ],
          ),
          if (_googlePayAvailable != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Google Pay: ${_googlePayAvailable! ? 'available' : 'not available'}',
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _payWithCard,
            child: const Text('Pay with card'),
          ),
          if (_applePayAvailable) ...<Widget>[
            const SizedBox(height: 24),
            TextField(
              controller: _applePayMerchantId,
              decoration: const InputDecoration(
                labelText: 'Apple merchant identifier',
              ),
            ),
            TextField(
              controller: _applePayCountry,
              decoration: const InputDecoration(labelText: 'Country code'),
            ),
            TextField(
              controller: _applePayMerchantName,
              decoration: const InputDecoration(labelText: 'Merchant name'),
            ),
            const SizedBox(height: 12),
            NgeniusApplePayButton(
              onPressed: _busy ? () {} : _payWithApplePay,
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Result: $_result',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

/// Converts an N-Genius minor-unit amount (`1250` is 12.50 AED) to the decimal
/// text Apple Pay expects, honouring the currency's exponent.
String minorUnitsToDecimal(num minorUnits, String currencyCode) {
  const threeDecimals = <String>{'BHD', 'IQD', 'JOD', 'KWD', 'LYD', 'OMR', 'TND'};
  const zeroDecimals = <String>{'CLP', 'ISK', 'JPY', 'KRW', 'UGX', 'VND', 'XAF', 'XOF'};
  final code = currencyCode.toUpperCase();
  final exponent = threeDecimals.contains(code)
      ? 3
      : zeroDecimals.contains(code)
          ? 0
          : 2;
  final units = minorUnits.round();
  if (exponent == 0) {
    return '$units';
  }
  final divisor = exponent == 3 ? 1000 : 100;
  final whole = units ~/ divisor;
  final fraction = (units % divisor).toString().padLeft(exponent, '0');
  return '$whole.$fraction';
}
