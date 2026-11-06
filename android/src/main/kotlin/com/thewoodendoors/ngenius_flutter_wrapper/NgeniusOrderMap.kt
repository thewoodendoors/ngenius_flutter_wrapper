package com.thewoodendoors.ngenius_flutter_wrapper

import payment.sdk.android.payments.PaymentsResult

/** Reads the URLs the SDK needs from an N-Genius order (the create-order response as a map). */
internal object NgeniusOrderMap {
    /** Google Pay readiness probe: cards with PAN_ONLY or CRYPTOGRAM_3DS auth on Visa and Mastercard. */
    const val IS_READY_TO_PAY_JSON =
        """{"apiVersion":2,"apiVersionMinor":0,"allowedPaymentMethods":[{"type":"CARD","parameters":{"allowedAuthMethods":["PAN_ONLY","CRYPTOGRAM_3DS"],"allowedCardNetworks":["VISA","MASTERCARD"]}}]}"""

    /** `_links.payment.href`: the hosted pay page URL; its `code` query parameter authorises the SDK. */
    fun payPageUrl(order: Map<*, *>): String? = href(asMap(order["_links"])?.get("payment"))

    /** `_links.payment-authorization.href`, or the same link under the first embedded payment. */
    fun authorizationUrl(order: Map<*, *>): String? =
        href(asMap(order["_links"])?.get("payment-authorization"))
            ?: href(asMap(firstPayment(order)?.get("_links"))?.get("payment-authorization"))

    private fun firstPayment(order: Map<*, *>): Map<*, *>? =
        (asMap(order["_embedded"])?.get("payment") as? List<*>)?.firstOrNull()?.let(::asMap)

    private fun asMap(value: Any?): Map<*, *>? = value as? Map<*, *>

    private fun href(link: Any?): String? =
        (asMap(link)?.get("href") as? String)?.takeIf { it.isNotBlank() }
}

/** Converts the SDK result into the `{status, reason}` map shared with Dart. */
internal object NgeniusResultMapper {
    fun toMap(result: PaymentsResult): Map<String, String?> {
        val (status, reason) = when (result) {
            PaymentsResult.Authorised -> "authorised" to null
            PaymentsResult.Success -> "success" to null
            PaymentsResult.PostAuthReview -> "post_auth_review" to null
            PaymentsResult.PartialAuthDeclined -> "partial" to "partial_auth_declined"
            PaymentsResult.PartialAuthDeclineFailed -> "partial" to "partial_auth_decline_failed"
            PaymentsResult.PartiallyAuthorised -> "partial" to "partially_authorised"
            is PaymentsResult.Failed -> "failed" to result.error.takeIf { it.isNotBlank() }
            PaymentsResult.Cancelled -> "cancelled" to null
        }
        return mapOf("status" to status, "reason" to reason)
    }
}
