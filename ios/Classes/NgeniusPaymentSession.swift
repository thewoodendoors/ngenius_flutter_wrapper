import Foundation
import NISdk
import PassKit

/// One payment attempt: receives the SDK's delegate callbacks and completes the Flutter call once.
final class NgeniusPaymentSession: NSObject, CardPaymentDelegate, ApplePayDelegate {
    typealias Completion = ([String: Any?]) -> Void

    private var completion: Completion?

    init(completion: @escaping Completion) {
        self.completion = completion
        super.init()
    }

    /// Delivers a result to Flutter. Later calls are ignored: the SDK can report an authorisation
    /// failure and then a payment failure for the same attempt.
    func finish(status: String, reason: String? = nil) {
        guard let completion = completion else {
            return
        }
        self.completion = nil
        completion(["status": status, "reason": reason])
    }

    // MARK: - CardPaymentDelegate

    func paymentDidComplete(with status: PaymentStatus) {
        switch status {
        case .PaymentSuccess:
            finish(status: "success")
        case .PaymentCancelled:
            finish(status: "cancelled")
        case .PaymentFailed:
            finish(status: "failed")
        case .PaymentPostAuthReview:
            finish(status: "post_auth_review")
        case .InValidRequest:
            finish(status: "invalid")
        case .PartialAuthDeclined:
            finish(status: "partial", reason: "partial_auth_declined")
        case .PartialAuthDeclineFailed:
            finish(status: "partial", reason: "partial_auth_decline_failed")
        case .PartiallyAuthorised:
            finish(status: "partial", reason: "partially_authorised")
        }
    }

    func authorizationDidComplete(with status: AuthorizationStatus) {
        if status == .AuthFailed {
            finish(status: "failed", reason: "authorization_failed")
        }
    }

    // ApplePayDelegate: every method is optional; the SDK's defaults (no shipping, no method
    // updates) are what a single-item payment needs.
}
