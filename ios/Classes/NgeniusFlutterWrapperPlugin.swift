import Flutter
import NISdk
import PassKit
import UIKit

/// Flutter side of the N-Genius Online iOS SDK (NISdk 6.1.6): card payments and Apple Pay.
public class NgeniusFlutterWrapperPlugin: NSObject, FlutterPlugin {
    static let channelName = "ngenius_flutter_wrapper"
    static let applePayButtonViewType = "ngenius_flutter_wrapper/apple_pay_button"

    /// The payment in progress. The SDK holds its CardPaymentDelegate weakly, so this is also what
    /// keeps the delegate alive until the SDK reports a result.
    private var session: NgeniusPaymentSession?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        let instance = NgeniusFlutterWrapperPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.register(ApplePayButtonFactory(messenger: registrar.messenger()), withId: applePayButtonViewType)
        // Sent to the gateway as X-NI-Platform; the SDK asks bridges to declare themselves.
        NISdk.sharedInstance.platform = .iOSFlutter
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "configure":
            configure(args)
            result(nil)
        case "payWithCard":
            payWithCard(args, result: result)
        case "payWithApplePay":
            payWithApplePay(args, result: result)
        case "isApplePayAvailable":
            result(isApplePayAvailable(args))
        case "isGooglePayAvailable":
            result(false)
        case "reset":
            session?.finish(status: "unknown", reason: "reset")
            session = nil
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - configure

    private func configure(_ args: [String: Any]) {
        let sdk = NISdk.sharedInstance
        if let language = args["language"] as? String, !language.isEmpty {
            sdk.setSDKLanguage(language: language)
        }
        if let show = args["showOrderAmount"] as? Bool {
            sdk.shouldShowOrderAmount = show
        }
        if let show = args["showCancelAlert"] as? Bool {
            sdk.shouldShowCancelAlert = show
        }
        sdk.setSDKColors(sdkColors: NgeniusColorMap.sdkColors(from: args["colors"] as? [String: Any]))
    }

    // MARK: - payWithCard / payWithApplePay

    private func payWithCard(_ args: [String: Any], result: @escaping FlutterResult) {
        guard session == nil else {
            return result(Self.error("busy", "A payment is already in progress."))
        }
        guard let order = Self.decodeOrder(args["order"]) else {
            return result(Self.error("invalid_order", Self.orderDecodeMessage))
        }
        guard order.orderLinks?.payPageLink != nil, order.orderLinks?.paymentAuthorizationLink != nil else {
            return result(Self.error("invalid_order", Self.orderLinksMessage))
        }
        guard let parent = Self.topViewController() else {
            return result(Self.error("no_activity", "No view controller to present the payment page from."))
        }
        if let timeoutMs = (args["threeDsTimeoutMs"] as? NSNumber)?.doubleValue {
            NISdk.sharedInstance.threeDSSessionTimeout = timeoutMs / 1000
        }
        let session = startSession(result)
        NISdk.sharedInstance.showCardPaymentViewWith(cardPaymentDelegate: session, overParent: parent, for: order)
    }

    private func payWithApplePay(_ args: [String: Any], result: @escaping FlutterResult) {
        guard session == nil else {
            return result(Self.error("busy", "A payment is already in progress."))
        }
        guard let order = Self.decodeOrder(args["order"]) else {
            return result(Self.error("invalid_order", Self.orderDecodeMessage))
        }
        guard order.orderLinks?.payPageLink != nil, order.orderLinks?.paymentAuthorizationLink != nil else {
            return result(Self.error("invalid_order", Self.orderLinksMessage))
        }
        guard order.embeddedData?.payment?.first?.paymentLinks?.applePayLink != nil else {
            return result(Self.error(
                "invalid_order",
                "Apple Pay is not enabled for this order: _embedded.payment[0]._links.payment:apple_pay is missing."
            ))
        }
        guard let request = Self.paymentRequest(from: args["applePay"] as? [String: Any]) else {
            return result(Self.error(
                "launch_failed",
                "The Apple Pay configuration needs merchantIdentifier, countryCode, currencyCode, merchantName and a decimal amount."
            ))
        }
        guard let parent = Self.topViewController() else {
            return result(Self.error("no_activity", "No view controller to present the Apple Pay sheet from."))
        }
        let session = startSession(result)
        // The SDK force-unwraps its ApplePayDelegate, so the session always serves as both delegates.
        NISdk.sharedInstance.initiateApplePayWith(
            applePayDelegate: session,
            cardPaymentDelegate: session,
            overParent: parent,
            for: order,
            with: request
        )
    }

    private func startSession(_ result: @escaping FlutterResult) -> NgeniusPaymentSession {
        let session = NgeniusPaymentSession { [weak self] payload in
            self?.session = nil
            result(payload)
        }
        self.session = session
        return session
    }

    private func isApplePayAvailable(_ args: [String: Any]) -> Bool {
        let networks = Self.networks(from: args["networks"] as? [String])
        return NISdk.sharedInstance.deviceSupportsApplePay()
            && PKPaymentAuthorizationController.canMakePayments(usingNetworks: networks)
    }

    // MARK: - Helpers

    static let orderDecodeMessage =
        "The order could not be decoded; pass the create-order response (it needs at least type, action and _links)."
    static let orderLinksMessage = "The order needs _links.payment.href and _links.payment-authorization.href."

    /// Re-encodes the Dart map as JSON and decodes it with the SDK's own Codable model.
    static func decodeOrder(_ value: Any?) -> OrderResponse? {
        guard let map = value as? [String: Any],
              JSONSerialization.isValidJSONObject(map),
              let data = try? JSONSerialization.data(withJSONObject: map) else {
            return nil
        }
        return try? OrderResponse.decodeFrom(data: data)
    }

    static func paymentRequest(from config: [String: Any]?) -> PKPaymentRequest? {
        guard let config = config,
              let merchantIdentifier = config["merchantIdentifier"] as? String, !merchantIdentifier.isEmpty,
              let countryCode = config["countryCode"] as? String, !countryCode.isEmpty,
              let currencyCode = config["currencyCode"] as? String, !currencyCode.isEmpty,
              let merchantName = config["merchantName"] as? String, !merchantName.isEmpty,
              let amountText = config["amount"] as? String else {
            return nil
        }
        let amount = NSDecimalNumber(string: amountText, locale: Locale(identifier: "en_US_POSIX"))
        guard amount != NSDecimalNumber.notANumber else {
            return nil
        }
        let request = PKPaymentRequest()
        request.merchantIdentifier = merchantIdentifier
        request.countryCode = countryCode
        request.currencyCode = currencyCode
        request.merchantCapabilities = merchantCapabilities
        request.supportedNetworks = networks(from: config["supportedNetworks"] as? [String])
        request.paymentSummaryItems = [PKPaymentSummaryItem(label: merchantName, amount: amount)]
        return request
    }

    /// 3-D Secure, credit and debit. Spelled as raw values because the Swift case names were renamed
    /// in the iOS 17 SDK (`capability3DS` became `threeDSecure`); the bit values are stable.
    static let merchantCapabilities = PKMerchantCapability(rawValue: (1 << 0) | (1 << 2) | (1 << 3))

    static func networks(from names: [String]?) -> [PKPaymentNetwork] {
        var networks: [PKPaymentNetwork] = []
        for name in names ?? ["visa", "masterCard", "amex"] {
            switch name.lowercased() {
            case "visa": networks.append(.visa)
            case "mastercard": networks.append(.masterCard)
            case "amex": networks.append(.amex)
            case "mada": networks.append(.mada)
            case "discover": networks.append(.discover)
            case "jcb": networks.append(.JCB)
            default: break
            }
        }
        return networks
    }

    /// The view controller on top of the key window of the active scene.
    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let window = scene?.keyWindow
            ?? scene?.windows.first { $0.isKeyWindow }
            ?? scene?.windows.first
        guard var top = window?.rootViewController else {
            return nil
        }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    static func error(_ code: String, _ message: String) -> FlutterError {
        return FlutterError(code: code, message: message, details: nil)
    }
}
