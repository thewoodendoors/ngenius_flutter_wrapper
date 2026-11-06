import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The native Apple Pay button (`PKPaymentButton`). Apple requires its own
/// artwork for the "Pay with Apple Pay" control, so this embeds it as a
/// platform view. Off iOS the widget renders nothing (`SizedBox.shrink`).
///
/// [type] is one of `plain`, `buy`, `setUp`, `inStore`, `donate`, `checkout`,
/// `book`, `subscribe`, `reload`, `addMoney`, `topUp`, `order`, `rent`,
/// `support`, `contribute`, `tip`, `continue`; [style] is `black`, `white`,
/// `whiteOutline` or `automatic`.
class NgeniusApplePayButton extends StatefulWidget {
  const NgeniusApplePayButton({
    super.key,
    required this.onPressed,
    this.type = 'buy',
    this.style = 'black',
    this.height = 48,
    this.cornerRadius = 8,
  });

  /// Platform view type registered by the iOS plugin.
  static const String viewType = 'ngenius_flutter_wrapper/apple_pay_button';

  /// Prefix of the per-view channel on which the native button reports taps.
  static const String channelPrefix =
      'ngenius_flutter_wrapper/apple_pay_button_';

  final VoidCallback onPressed;
  final String type;
  final String style;
  final double height;
  final double cornerRadius;

  @override
  State<NgeniusApplePayButton> createState() => _NgeniusApplePayButtonState();
}

class _NgeniusApplePayButtonState extends State<NgeniusApplePayButton> {
  MethodChannel? _channel;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: widget.height,
      child: UiKitView(
        viewType: NgeniusApplePayButton.viewType,
        creationParams: <String, Object?>{
          'type': widget.type,
          'style': widget.style,
          'cornerRadius': widget.cornerRadius,
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      ),
    );
  }

  void _onPlatformViewCreated(int viewId) {
    _channel?.setMethodCallHandler(null);
    final channel = MethodChannel('${NgeniusApplePayButton.channelPrefix}$viewId');
    channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onPressed' && mounted) {
        widget.onPressed();
      }
    });
    _channel = channel;
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }
}
