package com.deva.assistant.services

import android.app.Notification
import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class NotificationReaderService : NotificationListenerService() {

    companion object {
        const val ACTION_NOTIFICATION_POSTED = "com.deva.assistant.NOTIFICATION_POSTED"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_PACKAGE = "package"
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d("NotificationReader", "DEVA Notification Listener Connected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName
        
        // Ignore system notifications or our own app
        if (packageName == "android" || packageName == "com.android.systemui" || packageName == applicationContext.packageName) {
            return
        }

        val extras = sbn.notification.extras
        val title = extras.getString(Notification.EXTRA_TITLE) ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""

        // Only broadcast if there's actual readable text
        if (title.isNotEmpty() || text.isNotEmpty()) {
            val intent = Intent(ACTION_NOTIFICATION_POSTED).apply {
                putExtra(EXTRA_PACKAGE, packageName)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_TEXT, text)
                setPackage(applicationContext.packageName)
            }
            sendBroadcast(intent)
            Log.d("NotificationReader", "Captured: $title - $text from $packageName")
        }
    }
}
