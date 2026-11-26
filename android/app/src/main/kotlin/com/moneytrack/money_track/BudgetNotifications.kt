package com.moneytrack.money_track

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native Android bridge for posting local push notifications (such as 80% and
 * 100% monthly spending limit alerts) over the "money_track/notifications"
 * MethodChannel.
 */
object BudgetNotifications {
    const val CHANNEL = "money_track/notifications"
    private const val NOTIFICATION_CHANNEL_ID = "budget_alerts"
    private const val NOTIFICATION_CHANNEL_NAME = "Budget Alerts"

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "showBudgetAlert" -> {
                val id = (call.arguments as? Map<*, *>)?.get("id") as? Int ?: 4300
                val title = (call.arguments as? Map<*, *>)?.get("title") as? String ?: "Budget alert"
                val body = (call.arguments as? Map<*, *>)?.get("body") as? String ?: ""
                show(context, id, title, body)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun show(context: Context, id: Int, title: String, body: String) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (!manager.areNotificationsEnabled()) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                NOTIFICATION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Alerts when monthly spending crosses 80% or 100% of your limit"
            }
            manager.createNotificationChannel(channel)
        }

        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return
        val tap = PendingIntent.getActivity(
            context,
            id,
            launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_capture)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(tap)
            .setAutoCancel(true)
            .build()

        manager.notify(id, notification)
    }
}
