package com.thewoodendoors.ngenius_flutter_wrapper

import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.activity.ComponentActivity
import com.google.android.gms.wallet.IsReadyToPayRequest
import com.google.android.gms.wallet.Wallet
import com.google.android.gms.wallet.WalletConstants
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import payment.sdk.android.SDKConfig
import payment.sdk.android.googlepay.GooglePayConfig
import payment.sdk.android.payments.PaymentsLauncher
import payment.sdk.android.payments.PaymentsRequest
import payment.sdk.android.payments.PaymentsResult

/**
 * Flutter side of the N-Genius Online Android SDK (payment-sdk 5.2.7).
 *
 * Card and Google Pay payments run in the SDK's own `PaymentsActivity`. It is started through
 * `PaymentsLauncher` (an `ActivityResultLauncher`) when the host activity is a `ComponentActivity`
 * such as `FlutterFragmentActivity` and the plugin was attached before the activity started, and
 * through `startActivityForResult` with [REQUEST_CODE_PAYMENT] otherwise. A plain `FlutterActivity`
 * extends `android.app.Activity`, so it always takes the second path. Both paths deliver the same
 * `PaymentsResult`.
 */
class NgeniusFlutterWrapperPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    private var channel: MethodChannel? = null
    private var applicationContext: Context? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var paymentsLauncher: PaymentsLauncher? = null
    private var pendingResult: Result? = null

    // FlutterPlugin

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        applicationContext = null
    }

    // ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attachActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        attachActivity(binding)

    override fun onDetachedFromActivity() {
        detachActivity()
        // The activity that hosted the payment page is gone for good: its result can no longer arrive.
        finish(STATUS_FAILED, "activity_detached")
    }

    private fun attachActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
        paymentsLauncher = createLauncher(binding.activity)
    }

    private fun detachActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        paymentsLauncher = null
    }

    private fun createLauncher(activity: Activity): PaymentsLauncher? {
        val componentActivity = activity as? ComponentActivity ?: return null
        return try {
            PaymentsLauncher(componentActivity) { result -> deliver(result) }
        } catch (e: IllegalStateException) {
            // registerForActivityResult() refuses registrations once the activity is STARTED (the
            // plugin was attached to a running activity); payWithCard then uses startActivityForResult.
            null
        }
    }

    // MethodCallHandler

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "configure" -> configure(call, result)
            "payWithCard" -> payWithCard(call, result)
            "payWithApplePay" ->
                result.error(ERROR_UNSUPPORTED_PLATFORM, "Apple Pay is only available on iOS.", null)
            "isApplePayAvailable" -> result.success(false)
            "isGooglePayAvailable" -> isGooglePayAvailable(call, result)
            "reset" -> {
                finish(STATUS_UNKNOWN, "reset")
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun configure(call: MethodCall, result: Result) {
        SDKConfig
            .shouldShowOrderAmount(call.argument<Boolean>("showOrderAmount") ?: true)
            .shouldShowCancelAlert(call.argument<Boolean>("showCancelAlert") ?: false)
        call.argument<String>("language")?.takeIf { it.isNotBlank() }?.let { SDKConfig.setLanguage(it) }
        // Colours are Android resources (payment_sdk_* overrides in the app); nothing to apply here.
        result.success(null)
    }

    private fun payWithCard(call: MethodCall, result: Result) {
        val binding = activityBinding
        if (binding == null) {
            result.error(ERROR_NO_ACTIVITY, "No foreground activity to open the payment page from.", null)
            return
        }
        if (pendingResult != null) {
            result.error(ERROR_BUSY, "A payment is already in progress.", null)
            return
        }
        val order = call.argument<Map<String, Any?>>("order")
        val payPageUrl = order?.let(NgeniusOrderMap::payPageUrl)
        val authorizationUrl = order?.let(NgeniusOrderMap::authorizationUrl)
        if (payPageUrl.isNullOrBlank() || authorizationUrl.isNullOrBlank()) {
            result.error(
                ERROR_INVALID_ORDER,
                "The order needs _links.payment.href and _links.payment-authorization.href.",
                null,
            )
            return
        }

        val builder = PaymentsRequest.builder()
            .gatewayAuthorizationUrl(authorizationUrl)
            .payPageUrl(payPageUrl)
        call.argument<Map<String, Any?>>("googlePay")?.let { googlePay ->
            val merchantGatewayId = googlePay["merchantGatewayId"] as? String
            if (!merchantGatewayId.isNullOrBlank()) {
                val environment = if (isProduction(googlePay["environment"] as? String)) {
                    GooglePayConfig.Environment.Production
                } else {
                    GooglePayConfig.Environment.Test
                }
                builder.setGooglePayConfig(
                    GooglePayConfig(environment = environment, merchantGatewayId = merchantGatewayId),
                )
            }
        }
        call.argument<Number>("threeDsTimeoutMs")?.let { builder.setThreeDSSessionTimeout(it.toLong()) }

        pendingResult = result
        try {
            val request = builder.build()
            val launcher = paymentsLauncher
            if (launcher != null) {
                launcher.launch(request)
            } else {
                binding.activity.startActivityForResult(request.toIntent(binding.activity), REQUEST_CODE_PAYMENT)
            }
        } catch (e: Exception) {
            pendingResult = null
            result.error(ERROR_LAUNCH_FAILED, e.message ?: "Could not open the payment page.", null)
        }
    }

    private fun isGooglePayAvailable(call: MethodCall, result: Result) {
        val context: Context = activityBinding?.activity ?: applicationContext ?: run {
            result.success(false)
            return
        }
        val environment = if (isProduction(call.argument<String>("environment"))) {
            WalletConstants.ENVIRONMENT_PRODUCTION
        } else {
            WalletConstants.ENVIRONMENT_TEST
        }
        try {
            val options = Wallet.WalletOptions.Builder().setEnvironment(environment).build()
            Wallet.getPaymentsClient(context, options)
                .isReadyToPay(IsReadyToPayRequest.fromJson(NgeniusOrderMap.IS_READY_TO_PAY_JSON))
                .addOnCompleteListener { task -> result.success(task.isSuccessful && task.result == true) }
        } catch (e: Exception) {
            result.success(false)
        }
    }

    // PluginRegistry.ActivityResultListener (startActivityForResult path)

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE_PAYMENT) return false
        if (pendingResult == null) return true
        if (resultCode == Activity.RESULT_CANCELED) {
            // PaymentsActivity answers RESULT_CANCELED both for the back button and for a confirmed
            // cancel alert; only the first carries a PaymentsResult extra.
            finish(STATUS_CANCELLED, null)
            return true
        }
        val paymentsResult = data?.let(::readPaymentsResult)
        if (paymentsResult != null) deliver(paymentsResult) else finish(STATUS_FAILED, "no_result")
        return true
    }

    @Suppress("DEPRECATION")
    private fun readPaymentsResult(intent: Intent): PaymentsResult? = try {
        intent.getParcelableExtra(EXTRA_PAYMENTS_RESULT)
    } catch (e: Exception) {
        null
    }

    private fun deliver(result: PaymentsResult) = finish(NgeniusResultMapper.toMap(result))

    private fun finish(status: String, reason: String?) = finish(mapOf("status" to status, "reason" to reason))

    private fun finish(payload: Map<String, String?>) {
        val result = pendingResult ?: return
        pendingResult = null
        result.success(payload)
    }

    private fun isProduction(environment: String?): Boolean =
        environment?.trim().equals("PRODUCTION", ignoreCase = true)

    companion object {
        const val CHANNEL_NAME = "ngenius_flutter_wrapper"

        /** Request code of the startActivityForResult path ("NG"). */
        const val REQUEST_CODE_PAYMENT = 0x4E47

        /** Extra under which PaymentsActivity returns its PaymentsResult (PaymentsLauncherContract.EXTRA_RESULT). */
        private const val EXTRA_PAYMENTS_RESULT = "card_payments_extra_result"

        private const val STATUS_FAILED = "failed"
        private const val STATUS_CANCELLED = "cancelled"
        private const val STATUS_UNKNOWN = "unknown"

        private const val ERROR_BUSY = "busy"
        private const val ERROR_NO_ACTIVITY = "no_activity"
        private const val ERROR_INVALID_ORDER = "invalid_order"
        private const val ERROR_UNSUPPORTED_PLATFORM = "unsupported_platform"
        private const val ERROR_LAUNCH_FAILED = "launch_failed"
    }
}
