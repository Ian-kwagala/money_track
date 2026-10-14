package com.moneytrack.money_track

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The app's only Android activity. Besides hosting Flutter, it connects the
 * "money_track/sms" method channel to [SmsCapture] while the UI is running,
 * so Dart can call into it and [SmsCapture.tellApp] can call back.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SmsCapture.CHANNEL)
        channel.setMethodCallHandler { call, result -> SmsCapture.handle(applicationContext, call, result) }
        SmsCapture.channel = channel
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // No UI to notify any more; SMS keep queueing until the app reopens.
        SmsCapture.channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
