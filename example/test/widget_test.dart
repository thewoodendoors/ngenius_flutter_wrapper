import 'package:flutter_test/flutter_test.dart';
import 'package:ngenius_flutter_wrapper_example/main.dart';

void main() {
  testWidgets('shows the payment form', (WidgetTester tester) async {
    await tester.pumpWidget(const NgeniusExampleApp());
    await tester.pump();

    expect(find.text('N-Genius example'), findsOneWidget);
    expect(find.text('Pay with card'), findsOneWidget);
    expect(find.text('Result: No payment yet.'), findsOneWidget);
  });

  test('minorUnitsToDecimal honours the currency exponent', () {
    expect(minorUnitsToDecimal(1250, 'AED'), '12.50');
    expect(minorUnitsToDecimal(1250, 'KWD'), '1.250');
    expect(minorUnitsToDecimal(1250, 'JPY'), '1250');
    expect(minorUnitsToDecimal(5, 'USD'), '0.05');
  });
}
