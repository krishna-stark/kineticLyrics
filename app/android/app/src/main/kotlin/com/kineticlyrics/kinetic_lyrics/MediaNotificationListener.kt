package com.kineticlyrics.kinetic_lyrics

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class MediaNotificationListener : NotificationListenerService() {
    override fun onListenerConnected() {
        super.onListenerConnected()
        NowPlayingBridge.refresh()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        NowPlayingBridge.refresh()
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        NowPlayingBridge.refresh()
    }
}
