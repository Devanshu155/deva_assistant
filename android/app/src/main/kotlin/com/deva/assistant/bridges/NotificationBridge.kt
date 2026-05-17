package com.deva.assistant.bridges

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.plugin.common.EventChannel
import com.deva.assistant.services.NotificationReaderService

class NotificationBridge(private val context: Context) : EventChannel.StreamHandler {

    private var eventSink: EventChannel.EventSink? = null
    
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == NotificationReaderService.ACTION_NOTIFICATION_POSTED) {
                val pkg = intent.getStringExtra(NotificationReaderService.EXTRA_PACKAGE) ?: ""
                val title = intent.getStringExtra(NotificationReaderService.EXTRA_TITLE) ?: ""
                val text = intent.getStringExtra(NotificationReaderService.EXTRA_TEXT) ?: ""
                
                eventSink?.success(mapOf(
                    "package" to pkg,
                    "title" to title,
                    "text" to text
                ))
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        val filter = IntentFilter(NotificationReaderService.ACTION_NOTIFICATION_POSTED)
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        try {
            context.unregisterReceiver(receiver)
        } catch (e: Exception) {
            // Already unregistered
        }
    }
}
