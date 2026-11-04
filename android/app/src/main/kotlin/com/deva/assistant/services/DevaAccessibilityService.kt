package com.deva.assistant.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.graphics.Rect
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * DEVA Screen Awareness — Accessibility Service.
 *
 * Key improvements over the original:
 * - Foreground package tracked on BOTH TYPE_WINDOW_STATE_CHANGED and
 *   TYPE_WINDOWS_CHANGED (fixes MCP not working on WhatsApp, Instagram, etc.)
 * - backgroundExecutor is shut down cleanly in onDestroy() to prevent zombie threads.
 * - findEditableDescendant recycles all non-result child nodes to prevent leaks.
 * - MAX_NODES increased to 350 (WhatsApp/Instagram have deep hierarchies).
 * - Detailed per-event logging for diagnostics.
 */
class DevaAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "DevaAccessibility"

        // Increased to handle deep UI hierarchies (WhatsApp, Instagram, Chrome).
        private const val MAX_NODES = 350
        private const val MAX_DEPTH = 20

        // Debounce: collapse rapid UI change events into a single capture.
        private const val CAPTURE_DEBOUNCE_MS = 120L
        private const val RETRY_DELAY_MS      = 280L

        // System packages whose window events should NOT update the foreground package.
        private val IGNORED_PACKAGES = setOf(
            "com.android.systemui",
            "com.android.launcher",
            "com.google.android.inputmethod.latin",
            "com.samsung.android.honeyboard",
        )

        @Volatile
        var lastCapturedText: String = ""
            private set

        @Volatile
        var lastForegroundPackage: String = ""
            private set

        @Volatile
        var lastCaptureTimeMs: Long = 0L
            private set

        @Volatile
        var instance: DevaAccessibilityService? = null
            private set

        fun getLatestSnapshotText(): String = lastCapturedText
    }

    private val mainHandler        = Handler(Looper.getMainLooper())
    private var backgroundExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var pendingCapture: Runnable? = null
    private var lastSnapshotHash   = 0

    // ── Lifecycle ─────────────────────────────────────────────────────────

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this

        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes =
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED  or
                AccessibilityEvent.TYPE_WINDOWS_CHANGED        or
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED       or
                AccessibilityEvent.TYPE_VIEW_CLICKED            or
                AccessibilityEvent.TYPE_VIEW_FOCUSED            or
                AccessibilityEvent.TYPE_VIEW_SCROLLED

            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC

            flags =
                AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS  or
                AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS  or
                AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS

            notificationTimeout = 80
            packageNames        = null   // null = listen to ALL packages
        }

        Log.i(TAG, "DEVA Screen Awareness service connected.")
        scheduleCapture(0)
    }

    override fun onInterrupt() {
        Log.w(TAG, "DEVA Screen Awareness interrupted.")
    }

    override fun onDestroy() {
        pendingCapture?.let(mainHandler::removeCallbacks)
        pendingCapture = null
        instance       = null

        // Cleanly shut down the background thread pool to prevent zombie threads.
        backgroundExecutor.shutdown()
        try {
            if (!backgroundExecutor.awaitTermination(2, TimeUnit.SECONDS)) {
                backgroundExecutor.shutdownNow()
            }
        } catch (_: InterruptedException) {
            backgroundExecutor.shutdownNow()
        }

        super.onDestroy()
        Log.i(TAG, "DEVA Screen Awareness service destroyed.")
    }

    // ── Event dispatch ────────────────────────────────────────────────────

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        when (event.eventType) {
            // App changed to foreground — most reliable package signal.
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                updateForegroundPackage(event.packageName?.toString(), "STATE_CHANGED")
                scheduleCapture(0)
            }

            // Window list changed — fires when WhatsApp, Instagram, Telegram, etc.
            // navigate internally without triggering TYPE_WINDOW_STATE_CHANGED.
            AccessibilityEvent.TYPE_WINDOWS_CHANGED -> {
                // Derive the foreground package from the focused interactive window.
                val focusedPkg = resolveFocusedWindowPackage()
                if (focusedPkg != null) {
                    updateForegroundPackage(focusedPkg, "WINDOWS_CHANGED")
                }
                scheduleCapture(0)
            }

            // Content / text changes — debounced to avoid flooding.
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED,
            AccessibilityEvent.TYPE_VIEW_CLICKED,
            AccessibilityEvent.TYPE_VIEW_FOCUSED,
            AccessibilityEvent.TYPE_VIEW_SCROLLED -> scheduleCapture(0)
        }
    }

    /**
     * Sets [lastForegroundPackage] from [rawPkg] if it is a non-blank,
     * non-system package. Logs the update for diagnostics.
     */
    private fun updateForegroundPackage(rawPkg: String?, source: String) {
        val pkg = rawPkg?.trim() ?: return
        if (pkg.isBlank() || IGNORED_PACKAGES.any { pkg.startsWith(it) }) return
        if (pkg != lastForegroundPackage) {
            lastForegroundPackage = pkg
            Log.d(TAG, "Foreground package → '$pkg' (via $source)")
        }
    }

    /**
     * Iterates the current window list to find the focused, interactive
     * (non-system) window and returns its package name.
     */
    private fun resolveFocusedWindowPackage(): String? {
        return try {
            windows
                ?.filter { it.type == AccessibilityWindowInfo.TYPE_APPLICATION && it.isFocused }
                ?.mapNotNull { window ->
                    val root = window.root
                    val pkg  = root?.packageName?.toString()
                    tryRecycle(root)
                    pkg
                }
                ?.firstOrNull { it.isNotBlank() && IGNORED_PACKAGES.none { sys -> it.startsWith(sys) } }
        } catch (e: Exception) {
            Log.w(TAG, "resolveFocusedWindowPackage failed", e)
            null
        }
    }

    // ── Screen capture (debounced, runs on background thread) ─────────────

    private fun scheduleCapture(retry: Int) {
        pendingCapture?.let(mainHandler::removeCallbacks)
        val runnable = Runnable {
            if (!backgroundExecutor.isShutdown) {
                backgroundExecutor.execute { captureScreen(retry) }
            }
        }
        pendingCapture = runnable
        val delayMs = if (retry == 0) CAPTURE_DEBOUNCE_MS else RETRY_DELAY_MS * retry
        mainHandler.postDelayed(runnable, delayMs)
    }

    private fun captureScreen(retry: Int) {
        val roots = activeRoots()
        if (roots.isEmpty()) {
            if (retry < 3) scheduleCapture(retry + 1)
            Log.w(TAG, "No accessibility roots found. retry=$retry")
            return
        }

        val builder   = StringBuilder()
        val pkgLabel  = lastForegroundPackage.ifBlank { "unknown" }
        builder.append("foreground_package=").append(pkgLabel).append('\n')
        var nodeCount = 0

        roots.forEachIndexed { index, root ->
            try {
                builder.append("window=").append(index).append('\n')
                nodeCount += appendNode(root, builder, 0, nodeCount)
            } catch (e: Exception) {
                Log.e(TAG, "Failed parsing accessibility root[$index]", e)
            } finally {
                tryRecycle(root)
            }
        }

        val snapshot = builder.toString().trim()
        if (snapshot.isBlank() || snapshot == "foreground_package=unknown") {
            if (retry < 3) scheduleCapture(retry + 1)
            return
        }

        val hash = snapshot.hashCode()
        if (hash != lastSnapshotHash) {
            lastSnapshotHash  = hash
            lastCapturedText  = snapshot
            lastCaptureTimeMs = SystemClock.elapsedRealtime()
            Log.d(TAG, "Screen captured: ${snapshot.length} chars from '$pkgLabel'")
        }
    }

    private fun activeRoots(): List<AccessibilityNodeInfo> {
        val roots = mutableListOf<AccessibilityNodeInfo>()
        try {
            windows
                ?.sortedByDescending { it.layer }
                ?.forEach { window -> window.root?.let { roots.add(it) } }
        } catch (e: Exception) {
            Log.w(TAG, "Could not read interactive windows", e)
        }

        if (roots.isEmpty()) {
            rootInActiveWindow?.let { roots.add(it) }
        }
        return roots
    }

    // ── Node traversal ────────────────────────────────────────────────────

    private fun appendNode(
        node: AccessibilityNodeInfo?,
        builder: StringBuilder,
        depth: Int,
        currentCount: Int,
    ): Int {
        if (node == null || depth > MAX_DEPTH || currentCount >= MAX_NODES) return 0

        var added = 0
        val text      = node.text?.toString()?.trim().orEmpty()
        val desc      = node.contentDescription?.toString()?.trim().orEmpty()
        val viewId    = node.viewIdResourceName?.trim().orEmpty()
        val className = node.className?.toString()?.trim().orEmpty()
        val pkgName   = node.packageName?.toString()?.trim().orEmpty()

        val interesting = text.isNotBlank() || desc.isNotBlank() || viewId.isNotBlank() ||
            node.isClickable || node.isScrollable || node.isEditable || node.isFocusable

        if (interesting) {
            val bounds = Rect()
            node.getBoundsInScreen(bounds)

            builder
                .append("depth=").append(depth)
                .append(" pkg=").append(pkgName.ifBlank { lastForegroundPackage.ifBlank { "unknown" } })
                .append(" class=").append(className.ifBlank { "unknown" })

            if (viewId.isNotBlank())  builder.append(" id=").append(viewId)
            if (text.isNotBlank())    builder.append(" text=\"").append(text.safeForLog()).append('"')
            if (desc.isNotBlank())    builder.append(" desc=\"").append(desc.safeForLog()).append('"')

            builder
                .append(" clickable=").append(node.isClickable)
                .append(" scrollable=").append(node.isScrollable)
                .append(" editable=").append(node.isEditable)
                .append(" enabled=").append(node.isEnabled)
                .append(" focused=").append(node.isFocused)
                .append(" bounds=")
                .append(bounds.left).append(',').append(bounds.top).append(',')
                .append(bounds.right).append(',').append(bounds.bottom)
                .append('\n')
            added++
        }

        for (i in 0 until node.childCount) {
            if (currentCount + added >= MAX_NODES) break
            val child = tryGetChild(node, i)
            try {
                added += appendNode(child, builder, depth + 1, currentCount + added)
            } finally {
                tryRecycle(child)
            }
        }
        return added
    }

    // ── Accessibility actions ─────────────────────────────────────────────

    fun performAction(actionType: String, target: String?, textToType: String?): Boolean {
        val action = actionType.lowercase(Locale.US).trim()
        if (action.isBlank()) return false

        val success = when (action) {
            "click"       -> withRoots { root -> clickFirstMatch(root, target.orEmpty()) }
            "type"        -> withRoots { root -> typeIntoMatch(root, target, textToType.orEmpty()) }
            "scroll_down" -> withRoots { root -> scrollFirst(root, AccessibilityNodeInfo.ACTION_SCROLL_FORWARD) }
            "scroll_up"   -> withRoots { root -> scrollFirst(root, AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD) }
            "go_back"     -> performGlobalAction(GLOBAL_ACTION_BACK)
            "go_home"     -> performGlobalAction(GLOBAL_ACTION_HOME)
            "notifications" -> performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS)
            "recents"     -> performGlobalAction(GLOBAL_ACTION_RECENTS)
            else          -> false
        }

        if (!success) {
            Log.w(TAG, "Action '$action' failed. target='$target' foreground='$lastForegroundPackage'")
        } else {
            Log.d(TAG, "Action '$action' succeeded on '$lastForegroundPackage'")
        }

        scheduleCapture(1)
        return success
    }

    private fun withRoots(action: (AccessibilityNodeInfo) -> Boolean): Boolean {
        val roots = activeRoots()
        try {
            for (root in roots) {
                if (action(root)) return true
            }
        } finally {
            roots.forEach(::tryRecycle)
        }
        return false
    }

    private fun clickFirstMatch(node: AccessibilityNodeInfo?, target: String): Boolean {
        if (node == null) return false
        if (target.isNotBlank() && nodeMatches(node, target)) {
            if (clickNodeOrParent(node)) return true
        }
        for (i in 0 until node.childCount) {
            val child = tryGetChild(node, i)
            try {
                if (clickFirstMatch(child, target)) return true
            } finally {
                tryRecycle(child)
            }
        }
        return false
    }

    private fun typeIntoMatch(
        node: AccessibilityNodeInfo?,
        target: String?,
        textToType: String,
    ): Boolean {
        if (node == null || textToType.isBlank()) return false

        val isTarget = target.isNullOrBlank() && (node.isFocused || node.isEditable) ||
            (!target.isNullOrBlank() && nodeMatches(node, target))

        if (isTarget) {
            val editable = if (node.isEditable) node else findEditableDescendant(node)
            if (editable != null) {
                editable.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                val args = Bundle().apply {
                    putCharSequence(
                        AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                        textToType,
                    )
                }
                return editable.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
            }
        }

        for (i in 0 until node.childCount) {
            val child = tryGetChild(node, i)
            try {
                if (typeIntoMatch(child, target, textToType)) return true
            } finally {
                tryRecycle(child)
            }
        }
        return false
    }

    private fun scrollFirst(node: AccessibilityNodeInfo?, action: Int): Boolean {
        if (node == null) return false
        if (node.isScrollable && node.performAction(action)) return true
        for (i in 0 until node.childCount) {
            val child = tryGetChild(node, i)
            try {
                if (scrollFirst(child, action)) return true
            } finally {
                tryRecycle(child)
            }
        }
        return false
    }

    /**
     * Finds the first editable descendant of [node].
     *
     * BUG FIX: The original code leaked AccessibilityNodeInfo objects by not
     * recycling children when a deeper ancestor returned the editable node.
     * Now every non-result child is always recycled in the finally block.
     */
    private fun findEditableDescendant(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (node == null) return null
        if (node.isEditable) return node

        for (i in 0 until node.childCount) {
            val child = tryGetChild(node, i) ?: continue
            val editable = findEditableDescendant(child)
            if (editable != null) {
                // Only recycle child if it is NOT the editable node itself.
                if (editable !== child) tryRecycle(child)
                return editable
            }
            // Child subtree had no editable — safe to recycle.
            tryRecycle(child)
        }
        return null
    }

    private fun nodeMatches(node: AccessibilityNodeInfo, target: String): Boolean {
        val needle = target.normalizeForMatch()
        if (needle.isBlank()) return false
        val candidates = listOf(
            node.text?.toString().orEmpty(),
            node.contentDescription?.toString().orEmpty(),
            node.viewIdResourceName.orEmpty(),
            node.className?.toString().orEmpty(),
        )
        return candidates.any { value ->
            val normalized = value.normalizeForMatch()
            normalized == needle || normalized.contains(needle)
        }
    }

    private fun clickNodeOrParent(node: AccessibilityNodeInfo): Boolean {
        if (!node.isEnabled) return false
        if (node.isClickable && node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) return true

        var parent = node.parent
        while (parent != null) {
            try {
                if (parent.isEnabled && parent.isClickable &&
                    parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                ) {
                    return true
                }
                val next = parent.parent
                tryRecycle(parent)
                parent = next
            } catch (e: Exception) {
                Log.w(TAG, "Parent click traversal failed", e)
                tryRecycle(parent)
                parent = null
            }
        }
        return false
    }

    // ── Utilities ─────────────────────────────────────────────────────────

    private fun tryGetChild(node: AccessibilityNodeInfo, index: Int): AccessibilityNodeInfo? {
        return try {
            node.getChild(index)
        } catch (e: Exception) {
            Log.w(TAG, "getChild($index) failed", e)
            null
        }
    }

    private fun tryRecycle(node: AccessibilityNodeInfo?) {
        if (node == null) return
        try {
            @Suppress("DEPRECATION")
            node.recycle()
        } catch (_: Exception) {
            // recycle() is a no-op on API 34+; ignore safely.
        }
    }

    private fun String.normalizeForMatch(): String =
        lowercase(Locale.US).replace(Regex("\\s+"), " ").trim()

    private fun String.safeForLog(): String =
        replace('\n', ' ').replace('\r', ' ').take(200)
}