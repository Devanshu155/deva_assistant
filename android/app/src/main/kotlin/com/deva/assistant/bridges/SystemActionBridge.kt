package com.deva.assistant.bridges

import android.app.Activity
import android.app.AppOpsManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Process
import android.provider.AlarmClock
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import com.deva.assistant.services.DevaAccessibilityService
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Handles system-level actions and protected Android settings navigation.
 *
 * Requires an [Activity] reference (held weakly to avoid leaks) so that
 * settings intents are launched within the existing task stack. This prevents
 * the black-screen artifact that occurs when Android rebuilds the task from an
 * application [Context] with FLAG_ACTIVITY_NEW_TASK.
 */
class SystemActionBridge(activity: Activity) {

    // Weak reference so we never prevent Activity from being GC'd.
    private val activityRef = WeakReference(activity)

    // Application context is safe to hold strongly — used as a fallback only.
    private val appContext: Context = activity.applicationContext

    companion object {
        private const val TAG = "SystemActionBridge"
        private const val TYPE_ACCESSIBILITY = "accessibility"
        private const val TYPE_NOTIFICATION = "notification"
        private const val TYPE_OVERLAY = "overlay"
        private const val TYPE_USAGE_ACCESS = "usage_access"
        private const val TYPE_APP_DETAILS = "app_details"
    }

    fun register(channel: MethodChannel) {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setAlarm"                   -> handleSetAlarm(call, result)
                "openNotificationSettings"   -> openPermissionSettings(TYPE_NOTIFICATION, result)
                "openAccessibilitySettings"  -> openPermissionSettings(TYPE_ACCESSIBILITY, result)
                "openOverlaySettings"        -> openPermissionSettings(TYPE_OVERLAY, result)
                "openUsageAccessSettings"    -> openPermissionSettings(TYPE_USAGE_ACCESS, result)
                "openPermissionSettings"     -> {
                    val type = call.argument<String>("type") ?: ""
                    openPermissionSettings(type, result)
                }
                "getPermissionStatuses"      -> handleGetPermissionStatuses(result)
                "getBatteryLevel"            -> handleGetBatteryLevel(result)
                "readScreen"                 -> handleReadScreen(result)
                "getForegroundApp"           -> handleGetForegroundApp(result)
                "performAccessibilityAction" -> handlePerformAccessibilityAction(call, result)
                else                         -> result.notImplemented()
            }
        }
    }

    // ── Alarm ────────────────────────────────────────────────────────────

    private fun handleSetAlarm(call: MethodCall, result: MethodChannel.Result) {
        val title     = call.argument<String>("title")    ?: "Reminder"
        val timeStr   = call.argument<String>("time")     ?: ""
        val recurring = call.argument<Boolean>("recurring") ?: false

        try {
            val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                putExtra(AlarmClock.EXTRA_MESSAGE, title)
                putExtra(AlarmClock.EXTRA_SKIP_UI, false)

                parseTime(timeStr)?.let { (hour, minute) ->
                    putExtra(AlarmClock.EXTRA_HOUR, hour)
                    putExtra(AlarmClock.EXTRA_MINUTES, minute)
                }

                if (recurring) {
                    putExtra(
                        AlarmClock.EXTRA_DAYS,
                        arrayListOf(
                            Calendar.MONDAY, Calendar.TUESDAY, Calendar.WEDNESDAY,
                            Calendar.THURSDAY, Calendar.FRIDAY, Calendar.SATURDAY,
                            Calendar.SUNDAY,
                        ),
                    )
                }
            }

            startActivitySafely(intent, "alarm")
            result.success("Alarm UI opened for $title")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set alarm", e)
            result.error("ALARM_ERROR", "Failed to set alarm: ${e.message}", null)
        }
    }

    // ── Permission Settings ───────────────────────────────────────────────

    private fun openPermissionSettings(type: String, result: MethodChannel.Result) {
        val normalized = type.lowercase(Locale.US).trim()
        val beforeStatus = when (normalized) {
            TYPE_ACCESSIBILITY, "screen_awareness", "screen" -> isAccessibilityServiceEnabled()
            TYPE_NOTIFICATION, "notification_access", "notifications" -> isNotificationListenerEnabled()
            TYPE_OVERLAY, "draw_over_apps" -> canDrawOverlays()
            TYPE_USAGE_ACCESS, "usage", "usage_stats" -> hasUsageStatsPermission()
            else -> false
        }
        Log.i(TAG, "Opening permission settings for type='$type' (current status: $beforeStatus)")
        try {
            val opened = openPermissionSettings(type)
            if (opened) {
                result.success(true)
            } else {
                Log.w(TAG, "No settings activity resolved for type='$type'")
                result.error("SETTINGS_ERROR", "No settings screen found for $type", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Could not open permission settings for '$type'", e)
            result.error("SETTINGS_ERROR", "Could not open settings for $type: ${e.message}", null)
        }
    }

    private fun openPermissionSettings(type: String): Boolean {
        val normalized = type.lowercase(Locale.US).trim()
        val appUri     = Uri.parse("package:${appContext.packageName}")

        val intents = when (normalized) {
            TYPE_ACCESSIBILITY, "screen_awareness", "screen" -> listOf(
                Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS),
                Intent(Settings.ACTION_SETTINGS),
            )
            TYPE_NOTIFICATION, "notification_access", "notifications" -> listOf(
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS),
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, appContext.packageName)
                },
                Intent(Settings.ACTION_SETTINGS),
            )
            TYPE_OVERLAY, "draw_over_apps" -> listOf(
                Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, appUri),
                Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION),
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, appUri),
                Intent(Settings.ACTION_SETTINGS),
            )
            TYPE_USAGE_ACCESS, "usage", "usage_stats" -> listOf(
                Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS),
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, appUri),
                Intent(Settings.ACTION_SETTINGS),
            )
            TYPE_APP_DETAILS, "app" -> listOf(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, appUri),
                Intent(Settings.ACTION_SETTINGS),
            )
            else -> listOf(Intent(Settings.ACTION_SETTINGS))
        }

        return intents.any { intent -> startActivitySafely(intent, normalized) }
    }

    /**
     * Launches [intent] preferring the live [Activity] so that settings open
     * within the current task stack (no black screen on return).
     *
     * Falls back to application context + FLAG_ACTIVITY_NEW_TASK only when
     * the Activity has already been destroyed.
     */
    private fun startActivitySafely(baseIntent: Intent, label: String): Boolean {
        val activity = activityRef.get()

        return try {
            if (activity != null && !activity.isFinishing && !activity.isDestroyed) {
                // Preferred path: launch inside the existing task — no task-stack rebuild,
                // so Flutter's surface remains live when the user presses Back.
                activity.startActivity(baseIntent)
                Log.i(TAG, "[$label] Launched from Activity: ${baseIntent.action}")
            } else {
                // Fallback: application context needs NEW_TASK to create a back-stack entry.
                val fallbackIntent = Intent(baseIntent).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                appContext.startActivity(fallbackIntent)
                Log.w(TAG, "[$label] Activity unavailable — launched from appContext: ${baseIntent.action}")
            }
            true
        } catch (e: ActivityNotFoundException) {
            Log.w(TAG, "[$label] No activity found for: ${baseIntent.action}", e)
            false
        } catch (e: SecurityException) {
            Log.e(TAG, "[$label] Security error: ${baseIntent.action}", e)
            false
        } catch (e: Exception) {
            Log.e(TAG, "[$label] Unexpected error: ${baseIntent.action}", e)
            false
        }
    }

    // ── Permission Status Queries ─────────────────────────────────────────

    private fun handleGetPermissionStatuses(result: MethodChannel.Result) {
        try {
            val statuses = mapOf(
                "accessibility"       to isAccessibilityServiceEnabled(),
                "screen_awareness"    to isAccessibilityServiceEnabled(),
                "notification"        to isNotificationListenerEnabled(),
                "overlay"             to canDrawOverlays(),
                "usage_access"        to hasUsageStatsPermission(),
                "foreground_package"  to DevaAccessibilityService.lastForegroundPackage,
                "last_screen_capture_ms" to DevaAccessibilityService.lastCaptureTimeMs,
            )
            Log.d(TAG, "Permission statuses: $statuses")
            result.success(statuses)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read permission statuses", e)
            result.error("PERMISSION_STATUS_ERROR", "Failed to read permission statuses", null)
        }
    }

    // ── Screen & Foreground App ───────────────────────────────────────────

    private fun handleReadScreen(result: MethodChannel.Result) {
        val text = DevaAccessibilityService.getLatestSnapshotText()
        val pkg  = DevaAccessibilityService.lastForegroundPackage
        Log.d(TAG, "readScreen: ${text.length} chars from pkg='$pkg'")
        if (text.isBlank()) {
            result.error(
                "SCREEN_ERROR",
                "Screen awareness is empty. Enable Accessibility and keep the target app visible.",
                null,
            )
        } else {
            result.success(text)
        }
    }

    private fun handleGetForegroundApp(result: MethodChannel.Result) {
        val pkg = DevaAccessibilityService.lastForegroundPackage
        val ts  = DevaAccessibilityService.lastCaptureTimeMs
        Log.d(TAG, "getForegroundApp: pkg='$pkg' at $ts")
        result.success(mapOf("package" to pkg, "captured_at" to ts))
    }

    // ── Battery ───────────────────────────────────────────────────────────

    private fun handleGetBatteryLevel(result: MethodChannel.Result) {
        try {
            val batteryStatus: Intent? = IntentFilter(Intent.ACTION_BATTERY_CHANGED).let { filter ->
                appContext.registerReceiver(null, filter)
            }
            val level    = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale    = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            val status   = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                           status == BatteryManager.BATTERY_STATUS_FULL

            if (level < 0 || scale <= 0) {
                result.success("Battery level is unavailable.")
                return
            }

            val pct      = (level * 100 / scale.toFloat()).toInt()
            val stateStr = if (charging) "charging" else "discharging"
            result.success("Battery is at $pct%, currently $stateStr.")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get battery level", e)
            result.error("BATTERY_ERROR", "Failed to get battery level: ${e.message}", null)
        }
    }

    // ── Accessibility Action ──────────────────────────────────────────────

    private fun handlePerformAccessibilityAction(call: MethodCall, result: MethodChannel.Result) {
        val actionType  = call.argument<String>("action") ?: ""
        val target      = call.argument<String>("target")
        val textToType  = call.argument<String>("text")

        val service = DevaAccessibilityService.instance
        if (service == null) {
            Log.w(TAG, "performAccessibilityAction called but service is null")
            result.error(
                "ACCESSIBILITY_ERROR",
                "Accessibility service is not running. Enable DEVA Screen Awareness in Settings.",
                null,
            )
            return
        }

        try {
            Log.d(TAG, "performAccessibilityAction: action=$actionType target=$target")
            val success = service.performAction(actionType, target, textToType)
            result.success(success)
        } catch (e: Exception) {
            Log.e(TAG, "Accessibility action failed", e)
            result.error("ACCESSIBILITY_ACTION_ERROR", "Action failed: ${e.message}", null)
        }
    }

    // ── Permission Check Helpers ──────────────────────────────────────────

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expected = ComponentName(appContext, DevaAccessibilityService::class.java).flattenToString()
        val enabled  = Settings.Secure.getInt(
            appContext.contentResolver,
            Settings.Secure.ACCESSIBILITY_ENABLED,
            0,
        ) == 1
        if (!enabled) return false

        val services = Settings.Secure.getString(
            appContext.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false

        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(services)
        for (svc in splitter) {
            if (svc.equals(expected, ignoreCase = true)) return true
        }
        return false
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val expected = ComponentName(
            appContext,
            com.deva.assistant.services.NotificationReaderService::class.java,
        ).flattenToString()

        val listeners = Settings.Secure.getString(
            appContext.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false

        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(listeners)
        for (listener in splitter) {
            if (listener.equals(expected, ignoreCase = true)) return true
        }
        return false
    }

    private fun canDrawOverlays(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(appContext)

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = appContext.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode   = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                appContext.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                appContext.packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    // ── Time parser ───────────────────────────────────────────────────────

    private fun parseTime(timeStr: String): Pair<Int, Int>? {
        if (timeStr.isBlank()) return null

        val formats = listOf(
            SimpleDateFormat("h:mm a",  Locale.US),
            SimpleDateFormat("hh:mm a", Locale.US),
            SimpleDateFormat("H:mm",    Locale.US),
            SimpleDateFormat("h a",     Locale.US),
        )

        for (fmt in formats) {
            try {
                val date = fmt.parse(timeStr.uppercase(Locale.US)) ?: continue
                val cal  = Calendar.getInstance().apply { time = date }
                return Pair(cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE))
            } catch (_: Exception) {
                // Try next format.
            }
        }
        return null
    }
}