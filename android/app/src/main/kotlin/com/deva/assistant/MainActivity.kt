package com.deva.assistant

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.deva.assistant.bridges.AppLauncherBridge
import com.deva.assistant.bridges.SystemActionBridge
import com.deva.assistant.bridges.NotificationBridge

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL_APP_LAUNCHER  = "com.deva.assistant/app_launcher"
        const val CHANNEL_SYSTEM_ACTION = "com.deva.assistant/system_action"
        const val CHANNEL_NOTIFICATIONS = "com.deva.assistant/notifications"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // AppLauncher bridge — opens/searches installed apps and Play Store
        AppLauncherBridge(this).register(
            MethodChannel(messenger, CHANNEL_APP_LAUNCHER)
        )

        // SystemAction bridge — settings navigation, permissions, screen reading.
        // IMPORTANT: Pass 'this' (Activity), not applicationContext.
        // SystemActionBridge holds it via WeakReference to prevent memory leaks.
        SystemActionBridge(this).register(
            MethodChannel(messenger, CHANNEL_SYSTEM_ACTION)
        )

        // Notification event stream — forwards incoming notifications to Flutter
        EventChannel(messenger, CHANNEL_NOTIFICATIONS)
            .setStreamHandler(NotificationBridge(this))
    }
}
