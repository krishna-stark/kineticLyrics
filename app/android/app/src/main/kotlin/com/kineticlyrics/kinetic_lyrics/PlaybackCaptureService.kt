package com.kineticlyrics.kinetic_lyrics

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class PlaybackCaptureService : Service() {
    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(
                    channelId,
                    "Private lyric learning",
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("Learning lyrics on this phone")
            .setContentText("Playback audio is processed locally and is not saved.")
            .setOngoing(true)
            .setSilent(true)
            .build()
        startForeground(notificationId, notification)

        @Suppress("DEPRECATION")
        val permissionData = intent?.getParcelableExtra<Intent>(extraPermissionData)
        val resultCode = intent?.getIntExtra(extraResultCode, Activity.RESULT_CANCELED)
            ?: Activity.RESULT_CANCELED
        if (permissionData == null || resultCode != Activity.RESULT_OK) {
            stopSelf()
            return START_NOT_STICKY
        }
        PlaybackCaptureBridge.start(this, resultCode, permissionData) { stopSelf() }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        PlaybackCaptureBridge.stop()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val extraResultCode = "resultCode"
        const val extraPermissionData = "permissionData"
        private const val channelId = "lyric_learning"
        private const val notificationId = 7043
    }
}
