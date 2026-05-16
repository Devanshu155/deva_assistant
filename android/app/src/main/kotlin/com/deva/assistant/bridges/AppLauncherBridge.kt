package com.deva.assistant.bridges

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * AppLauncherBridge — opens installed apps via Android intents.
 * Called from Flutter via MethodChannel when Groq returns an open_app tool call.
 */
class AppLauncherBridge(private val context: Context) {

    fun register(channel: MethodChannel) {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "openApp" -> handleOpenApp(call, result)
                else      -> result.notImplemented()
            }
        }
    }

    private fun handleOpenApp(call: MethodCall, result: MethodChannel.Result) {
        val appName     = call.argument<String>("app_name") ?: ""
        val packageName = call.argument<String>("package_name")

        // Try by exact package name first (most reliable)
        if (!packageName.isNullOrEmpty()) {
            val launched = launchByPackage(packageName)
            if (launched) {
                result.success("Opened app.")
                return
            }
        }

        // Fallback: fuzzy search among installed apps by name
        val found = findPackageByName(appName)
        if (found != null) {
            val launched = launchByPackage(found)
            if (launched) {
                result.success("Opened $appName.")
                return
            }
        }

        result.error("APP_NOT_FOUND", "Could not find app: $appName", null)
    }

    private fun launchByPackage(pkg: String): Boolean {
        return try {
            val intent = context.packageManager.getLaunchIntentForPackage(pkg)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                true
            } else false
        } catch (e: Exception) {
            false
        }
    }

    private fun findPackageByName(name: String): String? {
        val pm = context.packageManager
        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val query = name.lowercase().trim()
        return apps.firstOrNull { app ->
            pm.getApplicationLabel(app).toString().lowercase().contains(query)
        }?.packageName
    }
}
