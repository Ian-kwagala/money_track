package com.moneytrack.money_track

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.Executors

/**
 * Native half of auto-capture; the Dart half is lib/services/capture/.
 *
 * [SmsReceiver] queues each incoming SMS here, even while the app is closed, and the
 * app collects the queue and reads the inbox over the "money_track/sms" channel.
 * Messages from ordinary phone numbers are dropped here, so personal SMS never reach
 * the app. Everything else is judged by the Dart parser, which keeps only money
 * messages.
 */
object SmsCapture {
    const val CHANNEL = "money_track/sms"
    private const val PREFS = "money_track_auto_capture"
    private const val KEY_ON = "on"
    private const val KEY_QUEUE = "queue"
    private const val MAX_QUEUED = 200
    private const val MAX_INBOX = 2000
    private const val NOTIFICATION_CHANNEL = "auto_capture"
    private const val NOTIFICATION_ID = 4201

    private val separators = Regex("[\\s\\-()]")
    private val personalNumber = Regex("^\\+?\\d{9,}$")
    private val currency = Regex("(?i)\\b(UGX|USHS?|SHS)\\b")
    private val movement = Regex("(?i)(received|sent|paid|withdrawn|transferred|deposit|credited|debited|trxn|transaction)")
    private val notMoney = Regex("(?i)\\b(OTP|verification code|failed|declined)\\b")

    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** Set while the app's UI is running, so it can be told about new messages. */
    @Volatile
    var channel: MethodChannel? = null

    /** Same rule as MoneyMessageParser.isPersonalNumber on the Dart side. */
    fun isPersonalNumber(sender: String): Boolean = personalNumber.matches(sender.replace(separators, ""))

    /** Cheap pre-check for the notification only; the Dart parser decides for real. */
    fun mightBeMoney(body: String): Boolean =
        currency.containsMatchIn(body) && movement.containsMatchIn(body) && !notMoney.containsMatchIn(body)

    fun isOn(context: Context): Boolean = prefs(context).getBoolean(KEY_ON, false)

    private fun setOn(context: Context, on: Boolean) {
        val edit = prefs(context).edit().putBoolean(KEY_ON, on)
        if (!on) edit.remove(KEY_QUEUE)
        edit.apply()
    }

    @Synchronized
    fun enqueue(context: Context, sender: String, body: String, receivedAt: Long) {
        val queue = JSONArray(prefs(context).getString(KEY_QUEUE, "[]"))
        queue.put(JSONObject().put("sender", sender).put("body", body).put("receivedAt", receivedAt))
        while (queue.length() > MAX_QUEUED) queue.remove(0)
        prefs(context).edit().putString(KEY_QUEUE, queue.toString()).commit()
    }

    @Synchronized
    private fun takeQueued(context: Context): List<Map<String, Any>> {
        val queue = JSONArray(prefs(context).getString(KEY_QUEUE, "[]"))
        prefs(context).edit().remove(KEY_QUEUE).commit()
        return (0 until queue.length()).map { i ->
            val o = queue.getJSONObject(i)
            mapOf("sender" to o.optString("sender"), "body" to o.optString("body"), "receivedAt" to o.optLong("receivedAt"))
        }
    }

    /** Inbox messages since [sinceMs], oldest first; the newest [MAX_INBOX] if there are more. */
    private fun readInbox(context: Context, sinceMs: Long): List<Map<String, Any>> {
        val out = ArrayList<Map<String, Any>>()
        context.contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE),
            "${Telephony.Sms.DATE} >= ?",
            arrayOf(sinceMs.toString()),
            "${Telephony.Sms.DATE} DESC",
        )?.use { c ->
            while (out.size < MAX_INBOX && c.moveToNext()) {
                val sender = c.getString(0) ?: continue
                val body = c.getString(1) ?: continue
                if (isPersonalNumber(sender)) continue
                out.add(mapOf("sender" to sender, "body" to body, "receivedAt" to c.getLong(2)))
            }
        }
        out.reverse()
        return out
    }

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setListening" -> {
                setOn(context, call.arguments as? Boolean ?: false)
                result.success(null)
            }
            "takeQueued" -> result.success(takeQueued(context))
            "readInbox" -> {
                val since = (call.arguments as? Number)?.toLong() ?: 0L
                io.execute {
                    try {
                        val messages = readInbox(context, since)
                        main.post { result.success(messages) }
                    } catch (e: SecurityException) {
                        main.post { result.error("permission", "SMS permission is off", null) }
                    } catch (e: Exception) {
                        main.post { result.error("inbox", e.message, null) }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    /** Tells the running app (if any) to collect the queue. */
    fun tellApp() {
        main.post { channel?.invokeMethod("queued", null) }
    }

    /** One notification, updated in place, so several messages don't pile up. */
    fun notifyNewMoneyMessage(context: Context, sender: String) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (!manager.areNotificationsEnabled()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(NOTIFICATION_CHANNEL, "Auto-capture", NotificationManager.IMPORTANCE_DEFAULT)
            channel.description = "New transactions found in your SMS"
            manager.createNotificationChannel(channel)
        }
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return
        val tap = PendingIntent.getActivity(
            context, 0, launch, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, NOTIFICATION_CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        // The message text is left out: notifications show on the lock screen.
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_capture)
            .setContentTitle("New transaction to review")
            .setContentText("From $sender · tap to confirm it")
            .setContentIntent(tap)
            .setAutoCancel(true)
            .build()
        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
