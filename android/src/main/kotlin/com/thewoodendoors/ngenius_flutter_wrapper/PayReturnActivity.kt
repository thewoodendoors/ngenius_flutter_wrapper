package com.thewoodendoors.ngenius_flutter_wrapper

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * The way back into the app from N-Genius's hosted payment page.
 *
 * An app that takes the card step on the hosted page (Network International's advice for
 * Multi-Currency Pricing: the mobile SDKs have no currency choice) opens the order's payment link
 * in a Chrome Custom Tab. The tab sits on top of the app's own activity in the same task. When the
 * payer is done, the merchant's return page sends the browser to
 * `<applicationId>.pay://return`, which this activity answers.
 *
 * A link straight to the app's main activity would not do: with the tab on top of it, a
 * `singleTop` main activity is started a second time above the tab, as a fresh Flutter instance
 * that knows nothing of the pay page. This activity starts the app's launch activity with
 * `CLEAR_TOP | SINGLE_TOP` instead: the instance that is already running comes back to the front
 * as it was, and everything above it (the tab, this activity) is finished.
 *
 * Nothing of the link is passed on. The link is no proof of a payment: the app asks its own
 * server, which reads the order from N-Genius, as it does after every return to the foreground.
 *
 * The link is kept from the other SDKs in the app as well. Analytics and attribution SDKs register
 * `Application.ActivityLifecycleCallbacks` and read the intent of every activity that is created;
 * AppsFlyer, for one, takes any `VIEW` link it finds there for a deep link and sends it to its
 * servers with the next launch. A merchant's return link may carry a payment number or a state
 * that is nobody else's business. Those callbacks run inside `super.onCreate()`, so the activity
 * swaps its intent for an empty one before that call.
 */
class PayReturnActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Before super.onCreate(), which is where the SDKs that watch activities see this one.
        intent = Intent()
        super.onCreate(savedInstanceState)
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        if (launch != null) {
            launch.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            startActivity(launch)
        }
        finish()
        // No animation of its own: the payer sees the tab close and the app underneath.
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }
}
