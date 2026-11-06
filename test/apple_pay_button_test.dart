import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngenius_flutter_wrapper/ngenius_flutter_wrapper.dart';

void main() {
  testWidgets('renders nothing off iOS', (WidgetTester tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: NgeniusApplePayButton(onPressed: () {})),
      ),
    );
    expect(find.byType(UiKitView), findsNothing);
    expect(tester.getSize(find.byType(NgeniusApplePayButton)), Size.zero);
  });

  testWidgets('creates the platform view on iOS and forwards taps',
      (WidgetTester tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final List<MethodCall> platformViewCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,
        (MethodCall call) async {
      platformViewCalls.add(call);
      return null;
    });
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null));

    // The override has to be cleared inside the test body: the binding checks
    // the foundation debug variables before the teardown callbacks run.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      int presses = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 200,
              child: NgeniusApplePayButton(
                onPressed: () => presses++,
                type: 'checkout',
                style: 'white',
                height: 40,
                cornerRadius: 4,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(UiKitView), findsOneWidget);
      expect(tester.getSize(find.byType(NgeniusApplePayButton)),
          const Size(200, 40));

      final MethodCall create = platformViewCalls
          .singleWhere((MethodCall c) => c.method == 'create');
      final Map<Object?, Object?> args =
          create.arguments as Map<Object?, Object?>;
      expect(args['viewType'], NgeniusApplePayButton.viewType);
      final Object? params = const StandardMessageCodec()
          .decodeMessage(ByteData.sublistView(args['params'] as Uint8List));
      expect(params, <Object?, Object?>{
        'type': 'checkout',
        'style': 'white',
        'cornerRadius': 4.0,
      });

      final int viewId = args['id'] as int;
      await messenger.handlePlatformMessage(
        '${NgeniusApplePayButton.channelPrefix}$viewId',
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('onPressed')),
        (ByteData? _) {},
      );
      expect(presses, 1);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
