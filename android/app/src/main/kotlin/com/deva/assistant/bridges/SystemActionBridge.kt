package com.deva.assistant.bridges

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.provider.AlarmClock
import android.provider.Settings
import com.deva.assistant.services.DevaAccessibilityService
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.*

/**
 * SystemActionBridge — handles system-level actions triggered by DEVA tool calls.
 * Currently supports: set alarm/reminder.
 */
class SystemActionBridge(private val context: Context) {

    fun register(channel: MethodChannel) {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setAlarm" -> handleSetAlarm(call, result)
                "openNotificationSettings" -> handleOpenNotificationSettings(result)
                "openAccessibilitySettings" -> handleOpenAccessibilitySettings(result)
                "getBatteryLevel" -> handleGetBatteryLevel(result)
                "readScreen" -> handleReadScreen(result)
                else       -> result.notImplemented()
            }
        }
    }

    private fun handleSetAlarm(call: MethodCall, result: MethodChannel.Result) {
        val title     = call.argument<String>("title") ?: "Reminder"
        val timeStr   = call.argument<String>("time") ?: ""
        val recurring = call.argument<Boolean>("recurring") ?: false

        try {
            val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                putExtra(AlarmClock.EXTRA_MESSAGE, title)
                putExtra(AlarmClock.EXTRA_SKIP_UI, false) // Show alarm UI to confirm
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

                // Parse hour/minute if a time string was provided
                parseTime(timeStr)?.let { (h, m) ->
                    putExtra(AlarmClock.EXTRA_HOUR, h)
                    putExtra(AlarmClock.EXTRA_MINUTES, m)
                }

                if (recurring) {
                    // Set for all days if recurring
                    val days = intArrayOf(
                        Calendar.MONDAY, Calendar.TUESDAY, Calendar.WEDNESDAY,
                        Calendar.THURSDAY, Calendar.FRIDAY, Calendar.SATURDAY, Calendar.SUNDAY
                    )
                    putExtra(AlarmClock.EXTRA_DAYS, days.toTypedArray())
                }
            }

            context.startActivity(intent)
            result.success("Alarm set: $title")
        } catch (e: Exception) {
            result.error("ALARM_ERROR", "Failed to set alarm: ${e.message}", null)
        }
    }

    private fun handleOpenNotificationSettings(result: MethodChannel.Result) {
        try {
            val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("SETTINGS_ERROR", "Could not open notification settings", null)
        }
    }

    private fun handleOpenAccessibilitySettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("SETTINGS_ERROR", "Could not open accessibility settings", null)
        }
    }

    private fun handleReadScreen(result: MethodChannel.Result) {
        val text = DevaAccessibilityService.lastCapturedText
        if (text.isEmpty()) {
            result.error("SCREEN_ERROR", "Could not read screen, or screen is empty. Make sure accessibility service is enabled.", null)
        } else {
            result.success(text)
        }
    }

    private fun handleGetBatteryLevel(result: MethodChannel.Result) {
        try {
            val batteryStatus: Intent? = IntentFilter(Intent.ACTION_BATTERY_CHANGED).let { ifilter ->
                context.registerReceiver(null, ifilter)
            }
            val level: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            val status: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            
            val isCharging: Boolean = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                                      status == BatteryManager.BATTERY_STATUS_FULL

            val batteryPct = level * 100 / scale.toFloat()
            val stateStr = if (isCharging) "charging" else "discharging"
            
            result.success("Battery is at ${batteryPct.toInt()}%, currently $stateStr.")
        } catch (e: Exception) {
            result.error("BATTERY_ERROR", "Failed to get battery level", null)
        }
    }

    /**
     * Attempt to parse hour/minute from a time string.
     * Handles formats like "8:30 AM", "14:00", "8 AM".
     */
    private fun parseTime(timeStr: String): Pair<Int, Int>? {
        if (timeStr.isBlank()) return null

        val formats = listOf(
            SimpleDateFormat("h:mm a", Locale.US),
            SimpleDateFormat("hh:mm a", Locale.US),
            SimpleDateFormat("H:mm", Locale.US),
            SimpleDateFormat("h a", Locale.US),
        )

        for (fmt in formats) {
            try {
                val date = fmt.parse(timeStr.uppercase()) ?: continue
                val cal  = Calendar.getInstance().apply { time = date }
                return Pair(cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE))
            } catch (_: Exception) {}
        }
        return null
    }
}
