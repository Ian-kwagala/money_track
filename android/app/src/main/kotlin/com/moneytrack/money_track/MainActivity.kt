package com.moneytrack.money_track

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SmsCapture.CHANNEL)
        channel.setMethodCallHandler { call, result -> SmsCapture.handle(applicationContext, call, result) }
        SmsCapture.channel = channel
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        SmsCapture.channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
