import Flutter
import PassKit
import UIKit

/// Creates native Apple Pay buttons (`PKPaymentButton`) for the Dart `NgeniusApplePayButton`.
final class ApplePayButtonFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return ApplePayButtonView(
            frame: frame,
            viewId: viewId,
            arguments: args as? [String: Any] ?? [:],
            messenger: messenger
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

/// One button; taps are reported as `onPressed` on `ngenius_flutter_wrapper/apple_pay_button_<viewId>`.
final class ApplePayButtonView: NSObject, FlutterPlatformView {
    private let container: UIView
    private let channel: FlutterMethodChannel

    init(frame: CGRect, viewId: Int64, arguments: [String: Any], messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "ngenius_flutter_wrapper/apple_pay_button_\(viewId)",
            binaryMessenger: messenger
        )
        container = UIView(frame: frame)
        super.init()

        let button = PKPaymentButton(
            paymentButtonType: Self.buttonType(arguments["type"] as? String),
            paymentButtonStyle: Self.buttonStyle(arguments["style"] as? String)
        )
        if let radius = (arguments["cornerRadius"] as? NSNumber)?.doubleValue {
            button.cornerRadius = CGFloat(radius)
        }
        button.addTarget(self, action: #selector(didPress), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    func view() -> UIView {
        return container
    }

    @objc private func didPress() {
        channel.invokeMethod("onPressed", arguments: nil)
    }

    static func buttonType(_ name: String?) -> PKPaymentButtonType {
        switch name ?? "" {
        case "plain": return .plain
        case "setUp": return .setUp
        case "inStore": return .inStore
        case "donate": return .donate
        case "checkout": return .checkout
        case "book": return .book
        case "subscribe": return .subscribe
        case "reload": return .reload
        case "addMoney": return .addMoney
        case "topUp": return .topUp
        case "order": return .order
        case "rent": return .rent
        case "support": return .support
        case "contribute": return .contribute
        case "tip": return .tip
        case "continue": return .`continue`
        default: return .buy
        }
    }

    static func buttonStyle(_ name: String?) -> PKPaymentButtonStyle {
        switch name ?? "" {
        case "white": return .white
        case "whiteOutline": return .whiteOutline
        case "automatic": return .automatic
        default: return .black
        }
    }
}
