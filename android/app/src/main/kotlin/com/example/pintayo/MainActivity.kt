package com.example.pintayo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pintayo/notifications")
            .setMethodCallHandler { call, result ->
                if (call.method != "ensureChannel") {
                    result.notImplemented()
                } else {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val channel = NotificationChannel(
                            "pintayo_messages", "Messages and friend requests", NotificationManager.IMPORTANCE_HIGH
                        ).apply { description = "A hello from your people on PinTayo" }
                        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
                    }
                    result.success(null)
                }
            }
    }
}
