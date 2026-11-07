package com.finance.spendo

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

class SpendoWalletNotificationListener : NotificationListenerService() {

    companion object {
        const val PREFS_NAME = "spendo_wallet_bridge_prefs"
        const val KEY_PENDING = "pending_wallet_notifications"

        private val WALLET_PACKAGES = setOf(
            "com.google.android.apps.walletnfcrel",
            "com.google.commerce.tapandpay.android.card.app",
            "com.samsung.android.spay",
            "com.samsung.android.spaymini",
            "il.co.cal.android",
            "com.ideomobile.leumicard",
            "com.isracard.isracard",
            "com.bnhp.payments.paymentsapp",
            "com.Plainram.hapoalim",
            "com.leumi.leumiwallet"
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val pkg = sbn.packageName ?: return
        if (pkg == applicationContext.packageName) return

        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim() ?: ""

        val body = if (bigText.isNotEmpty()) bigText else text
        val combined = "$title\n$body".trim()
        if (combined.isEmpty()) return

        val isKnownWalletPkg = WALLET_PACKAGES.contains(pkg)
        val hasCurrency = combined.contains("₪") ||
                combined.contains("ש\"ח") ||
                combined.contains("שח") ||
                combined.contains("ILS", ignoreCase = true)
        val hasPaymentKeyword = combined.contains("שולם") ||
                combined.contains("חיוב") ||
                combined.contains("עסקה") ||
                combined.contains("רכישה") ||
                combined.contains("Paid", ignoreCase = true) ||
                combined.contains("Google Pay", ignoreCase = true) ||
                combined.contains("Apple Pay", ignoreCase = true)

        if (!isKnownWalletPkg && !(hasCurrency && hasPaymentKeyword)) {
            return
        }
        if (!hasCurrency) return

        val source = when {
            pkg.contains("walletnfcrel") || pkg.contains("tapandpay") || combined.contains("Google Pay", ignoreCase = true) -> "google_pay"
            pkg.contains("spay") -> "samsung_pay"
            pkg.contains("cal") -> "cal"
            pkg.contains("leumicard") -> "max"
            pkg.contains("isracard") -> "isracard"
            else -> "wallet"
        }

        val payload = JSONObject().apply {
            put("title", title)
            put("body", body)
            put("text", combined)
            put("source", source)
            put("timestamp", sbn.postTime)
        }.toString()

        val delivered = MainActivity.deliverLiveWalletNotification(payload)
        if (!delivered) {
            savePendingNotification(applicationContext, payload)
        }
    }

    private fun savePendingNotification(context: Context, payloadJson: String) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_PENDING, "[]") ?: "[]"
            val arr = JSONArray(raw)
            arr.put(JSONObject(payloadJson))
            prefs.edit().putString(KEY_PENDING, arr.toString()).apply()
        } catch (_: Exception) {
        }
    }
}
