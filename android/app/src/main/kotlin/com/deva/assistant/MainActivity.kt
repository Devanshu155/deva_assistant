package com.deva.assistant

import android.content.Intent
import android.net.Uri
import android.provider.AlarmClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.deva.assistant.bridges.AppLauncherBridge
import com.deva.assistant.bridges.SystemActionBridge

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL_APP_LAUNCHER   = "com.deva.assistant/app_launcher"
        const val CHANNEL_SYSTEM_ACTION  = "com.deva.assistant/system_action"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register native bridges with the Flutter engine
        AppLauncherBridge(this).register(
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_APP_LAUNCHER)
        )
        SystemActionBridge(this).register(
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SYSTEM_ACTION)
        )
    }
}
