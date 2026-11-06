# ngenius_flutter_wrapper_example

Demonstrates the `ngenius_flutter_wrapper` plugin without any backend: paste an order created with
`tool/sandbox_order.py` (or pass `--dart-define=ORDER_JSON_FILE=<path on the device>`), toggle English /
Arabic, pay with card (a Google Pay button appears on Android when `merchantGatewayId` and the
environment are filled in), or tap the Apple Pay button on an iPhone with Apple Pay set up.

iOS needs the Apple Pay capability with your merchant identifier in `Runner.xcodeproj` before the
button can complete a payment.
