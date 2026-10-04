package com.example.shahin_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // قناة إشعارات بأهمية عالية ليظهر الإشعار منبثقاً مع صوت
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "shahin_default",
                "إشعارات شاهين",
                NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "إشعارات الطلبات والرحلات"
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }
}
