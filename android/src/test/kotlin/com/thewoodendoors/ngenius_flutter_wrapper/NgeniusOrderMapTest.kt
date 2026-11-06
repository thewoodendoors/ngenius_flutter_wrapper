package com.thewoodendoors.ngenius_flutter_wrapper

import payment.sdk.android.payments.PaymentsResult
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/*
 * JVM unit tests of the pure helpers. Run them from `example/android` with
 * `./gradlew :ngenius_flutter_wrapper:testDebugUnitTest` once the example app has been built.
 */
internal class NgeniusOrderMapTest {
    private val order: Map<String, Any?> = mapOf(
        "_links" to mapOf(
            "payment" to mapOf("href" to "https://paypage.sandbox.ngenius-payments.com/?code=abc"),
            "payment-authorization" to mapOf(
                "href" to "https://api-gateway.sandbox.ngenius-payments.com/transactions/paymentAuthorization",
            ),
        ),
        "_embedded" to mapOf(
            "payment" to listOf(
                mapOf("_links" to mapOf("payment:card" to mapOf("href" to "https://example.invalid/card"))),
            ),
        ),
    )

    @Test
    fun readsThePayPageUrl() {
        assertEquals("https://paypage.sandbox.ngenius-payments.com/?code=abc", NgeniusOrderMap.payPageUrl(order))
    }

    @Test
    fun readsTheAuthorizationUrlFromTheOrderLinks() {
        assertEquals(
            "https://api-gateway.sandbox.ngenius-payments.com/transactions/paymentAuthorization",
            NgeniusOrderMap.authorizationUrl(order),
        )
    }

    @Test
    fun fallsBackToTheEmbeddedPaymentLinks() {
        val embeddedOnly = mapOf(
            "_embedded" to mapOf(
                "payment" to listOf(
                    mapOf("_links" to mapOf("payment-authorization" to mapOf("href" to "https://example.invalid/auth"))),
                ),
            ),
        )
        assertEquals("https://example.invalid/auth", NgeniusOrderMap.authorizationUrl(embeddedOnly))
    }

    @Test
    fun missingOrMalformedLinksGiveNull() {
        assertNull(NgeniusOrderMap.payPageUrl(emptyMap<String, Any?>()))
        assertNull(NgeniusOrderMap.authorizationUrl(mapOf("_links" to "not a map")))
        assertNull(NgeniusOrderMap.payPageUrl(mapOf("_links" to mapOf("payment" to mapOf("href" to "  ")))))
    }

    @Test
    fun mapsEverySdkResult() {
        assertEquals(mapOf("status" to "authorised", "reason" to null), NgeniusResultMapper.toMap(PaymentsResult.Authorised))
        assertEquals(mapOf("status" to "success", "reason" to null), NgeniusResultMapper.toMap(PaymentsResult.Success))
        assertEquals(mapOf("status" to "post_auth_review", "reason" to null), NgeniusResultMapper.toMap(PaymentsResult.PostAuthReview))
        assertEquals(mapOf("status" to "partial", "reason" to "partial_auth_declined"), NgeniusResultMapper.toMap(PaymentsResult.PartialAuthDeclined))
        assertEquals(mapOf("status" to "partial", "reason" to "partial_auth_decline_failed"), NgeniusResultMapper.toMap(PaymentsResult.PartialAuthDeclineFailed))
        assertEquals(mapOf("status" to "partial", "reason" to "partially_authorised"), NgeniusResultMapper.toMap(PaymentsResult.PartiallyAuthorised))
        assertEquals(mapOf("status" to "failed", "reason" to "Declined"), NgeniusResultMapper.toMap(PaymentsResult.Failed("Declined")))
        assertEquals(mapOf("status" to "failed", "reason" to null), NgeniusResultMapper.toMap(PaymentsResult.Failed("")))
        assertEquals(mapOf("status" to "cancelled", "reason" to null), NgeniusResultMapper.toMap(PaymentsResult.Cancelled))
    }
}
