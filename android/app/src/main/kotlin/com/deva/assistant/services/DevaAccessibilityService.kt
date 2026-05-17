package com.deva.assistant.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log

class DevaAccessibilityService : AccessibilityService() {

    companion object {
        var lastCapturedText: String = ""
        private const val TAG = "DevaAccessibility"
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "DEVA Screen Awareness Connected")
        val info = AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        this.serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        
        // We capture the window content continuously so it's always ready when the user asks
        val rootNode = rootInActiveWindow
        if (rootNode != null) {
            val builder = StringBuilder()
            extractText(rootNode, builder)
            val newText = builder.toString().trim()
            if (newText.isNotEmpty()) {
                lastCapturedText = newText
            }
            rootNode.recycle()
        }
    }

    private fun extractText(node: AccessibilityNodeInfo?, builder: StringBuilder) {
        if (node == null) return
        
        if (node.text != null) {
            builder.append(node.text).append("\n")
        } else if (node.contentDescription != null) {
            builder.append(node.contentDescription).append("\n")
        }
        
        for (i in 0 until node.childCount) {
            extractText(node.getChild(i), builder)
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "DEVA Screen Awareness Interrupted")
    }
}
