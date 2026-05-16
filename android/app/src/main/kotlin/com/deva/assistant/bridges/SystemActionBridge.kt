package com.deva.assistant.bridges

import android.content.Context
import android.content.Intent
import android.provider.AlarmClock
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
