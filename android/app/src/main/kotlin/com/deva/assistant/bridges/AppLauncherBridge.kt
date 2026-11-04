package com.deva.assistant.bridges

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * AppLauncherBridge — opens installed apps and the Google Play Store via Android intents.
 * Called from Flutter via MethodChannel when the AI returns an open_app or install_app tool call.
 */
class AppLauncherBridge(private val context: Context) {

    companion object {
        private const val TAG = "AppLauncherBridge"
        private const val PLAY_STORE_PACKAGE = "com.android.vending"
    }

    fun register(channel: MethodChannel) {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "openApp", "launchApp" -> handleOpenApp(call, result)
                "playOnYoutube"        -> handlePlayOnYoutube(call, result)
                "installApp"           -> handleInstallApp(call, result)
                else                   -> result.notImplemented()
            }
        }
    }

    // ── Open App ─────────────────────────────────────────────────────────

    private fun handleOpenApp(call: MethodCall, result: MethodChannel.Result) {
        val appName     = call.argument<String>("app_name")    ?: call.argument<String>("appName")     ?: ""
        val packageName = call.argument<String>("package_name") ?: call.argument<String>("packageName")

        Log.d(TAG, "openApp: appName='$appName' packageName='$packageName'")

        // Priority 1: Launch by explicit package name (most reliable)
        if (!packageName.isNullOrEmpty()) {
            if (launchByPackage(packageName)) {
                Log.i(TAG, "Launched '$packageName' by exact package name.")
                result.success("Opened $appName.")
                return
            }
        }

        // Priority 2: Fuzzy name search among all installed apps
        val found = findPackageByName(appName)
        if (found != null && launchByPackage(found)) {
            Log.i(TAG, "Launched '$found' by fuzzy name match for '$appName'.")
            result.success("Opened $appName.")
            return
        }

        Log.w(TAG, "App not found: appName='$appName' packageName='$packageName'")
        result.error("APP_NOT_FOUND", "Could not find app: $appName", null)
    }

    // ── YouTube ───────────────────────────────────────────────────────────

    private fun handlePlayOnYoutube(call: MethodCall, result: MethodChannel.Result) {
        val query = call.argument<String>("query") ?: ""
        Log.d(TAG, "playOnYoutube: query='$query'")
        try {
            val intent = Intent(Intent.ACTION_SEARCH).apply {
                setPackage("com.google.android.youtube")
                putExtra("query", query)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            result.success("Playing '$query' on YouTube.")
        } catch (e: ActivityNotFoundException) {
            Log.w(TAG, "YouTube app not found — falling back to web URL", e)
            // Fallback: open YouTube search in browser
            val fallbackUri = Uri.parse(
                "https://www.youtube.com/results?search_query=${Uri.encode(query)}"
            )
            val browserIntent = Intent(Intent.ACTION_VIEW, fallbackUri).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                context.startActivity(browserIntent)
                result.success("Opening YouTube search in browser.")
            } catch (e2: Exception) {
                result.error("YOUTUBE_NOT_FOUND", "Could not open YouTube: ${e2.message}", null)
            }
        } catch (e: Exception) {
            result.error("YOUTUBE_ERROR", "YouTube launch failed: ${e.message}", null)
        }
    }

    // ── Install App (Play Store) ──────────────────────────────────────────

    private fun handleInstallApp(call: MethodCall, result: MethodChannel.Result) {
        val appName     = call.argument<String>("app_name")    ?: ""
        val packageName = call.argument<String>("package_name") ?: call.argument<String>("packageName")

        Log.d(TAG, "installApp: appName='$appName' packageName='$packageName'")

        if (appName.isEmpty() && packageName.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "app_name or package_name must be provided", null)
            return
        }

        // Priority 1: Direct install page by package ID — most friction-free experience.
        if (!packageName.isNullOrEmpty()) {
            if (openPlayStorePage("market://details?id=$packageName", appName, result)) return
        }

        // Priority 2: Search by app name in Play Store.
        val searchQuery = Uri.encode(appName)
        if (openPlayStorePage("market://search?q=$searchQuery&c=apps", appName, result)) return

        // Priority 3: Web fallback (Play Store not installed — rare but possible on some devices).
        val webUri = if (!packageName.isNullOrEmpty()) {
            "https://play.google.com/store/apps/details?id=$packageName"
        } else {
            "https://play.google.com/store/search?q=$searchQuery&c=apps"
        }
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(webUri)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            context.startActivity(intent)
            result.success("Opened Play Store in browser to find $appName.")
            Log.i(TAG, "Play Store web fallback opened for '$appName'.")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open Play Store for '$appName'", e)
            result.error("PLAY_STORE_ERROR", "Could not open Play Store: ${e.message}", null)
        }
    }

    /**
     * Attempts to open a Play Store [marketUri]. Returns true and calls [result.success]
     * if the intent resolved, false otherwise.
     */
    private fun openPlayStorePage(
        marketUri: String,
        appLabel: String,
        result: MethodChannel.Result,
    ): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(marketUri)).apply {
                setPackage(PLAY_STORE_PACKAGE)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            Log.i(TAG, "Play Store opened: $marketUri")
            result.success("Opened Play Store for $appLabel.")
            true
        } catch (e: ActivityNotFoundException) {
            Log.w(TAG, "Play Store not available for URI: $marketUri")
            false
        } catch (e: Exception) {
            Log.e(TAG, "Play Store intent failed: $marketUri", e)
            false
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private fun launchByPackage(pkg: String): Boolean {
        return try {
            val intent = context.packageManager.getLaunchIntentForPackage(pkg)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                true
            } else {
                Log.w(TAG, "No launch intent for package: $pkg")
                false
            }
        } catch (e: Exception) {
            Log.w(TAG, "launchByPackage failed for '$pkg'", e)
            false
        }
    }

    private fun findPackageByName(name: String): String? {
        if (name.isBlank()) return null
        val pm    = context.packageManager
        val apps  = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val query = name.lowercase().trim()
        val match = apps.firstOrNull { app ->
            pm.getApplicationLabel(app).toString().lowercase().contains(query)
        }
        if (match == null) Log.w(TAG, "No installed app matched name='$name'")
        return match?.packageName
    }
}
