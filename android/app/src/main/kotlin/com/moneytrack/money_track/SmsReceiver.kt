package com.moneytrack.money_track

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Receives every incoming SMS, including while the app is closed, and hands the ones
 * not sent from a personal phone number to [SmsCapture]. Only the system can send this
 * broadcast (the manifest requires BROADCAST_SMS), so other apps can't fake one.
 */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        if (!SmsCapture.isOn(context)) return
        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        val now = System.currentTimeMillis()
        var queued = false
        var moneyFrom: String? = null
        // A long SMS arrives in several parts; join them back up per sender.
        for ((sender, messages) in parts.filterNotNull().groupBy { it.originatingAddress ?: "" }) {
            if (sender.isEmpty() || SmsCapture.isPersonalNumber(sender)) continue
            val body = messages.joinToString("") { it.messageBody ?: "" }
            if (body.isBlank()) continue
            SmsCapture.enqueue(context, sender, body, now)
            queued = true
            if (SmsCapture.mightBeMoney(body)) moneyFrom = sender
        }
        moneyFrom?.let { SmsCapture.notifyNewMoneyMessage(context, it) }
        if (queued) SmsCapture.tellApp()
    }
}
