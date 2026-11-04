# Comprehensive Optimization and Refactoring Plan

This plan outlines the complete debugging, optimization, and refactoring process for the DEVA Assistant application, addressing all 14 points requested to make every feature production-ready.

## User Review Required

> [!IMPORTANT]
> The changes proposed here will touch nearly every core system of the app (Flutter and Android Native). Please review the phases carefully before we begin.

## Open Questions

> [!WARNING]
> - Are there any specific test devices or Android versions where the black screen issue is most prominent?
> - For MCP not working outside YouTube, does the AccessibilityService currently have hardcoded package filters, or is the screen parsing logic failing on other UI hierarchies?

## Proposed Changes

### Phase 1: Permission System & Lifecycle Handling (Bug Detection & UI Improvements)

**Root Cause of Black Screen:** The `SystemActionBridge.kt` is currently launching system settings intents with `Intent.FLAG_ACTIVITY_NEW_TASK` and `Intent.FLAG_ACTIVITY_CLEAR_TOP`. `CLEAR_TOP` is likely destroying the Flutter Activity, resulting in a black screen when the user attempts to return from the settings screen. Furthermore, Flutter side needs proper `WidgetsBindingObserver` to detect when the app returns from background to refresh permission states and show a loading indicator.

#### [MODIFY] `SystemActionBridge.kt`
- Remove `Intent.FLAG_ACTIVITY_CLEAR_TOP` when launching settings intents.
- Ensure `Activity` context is used gracefully if available, or just `NEW_TASK` from application context.

#### [MODIFY] `SettingsScreen.dart` & `AssistantProvider.dart`
- Implement `WidgetsBindingObserver` to track app lifecycle states (resumed, paused).
- Automatically re-check permission statuses upon returning to the app.
- Add Loading state indicators during transition to prevent UI freezing.
- Handle "denied" states explicitly without breaking the UI.

### Phase 2: MCP Refactoring & Universal App Awareness

**Root Cause of MCP App Limitation:** The Accessibility Service and Screen Parsing logic likely have limitations or hardcoded logic tailored to YouTube's UI hierarchy, or it fails to correctly capture the `lastForegroundPackage` for other apps due to window change event handling.

#### [MODIFY] `DevaAccessibilityService.kt`
- Refactor `onAccessibilityEvent` to correctly identify and update `lastForegroundPackage` for *every* installed app on `TYPE_WINDOW_STATE_CHANGED` and `TYPE_WINDOW_CONTENT_CHANGED`.
- Optimize the recursive view hierarchy parsing to prevent ANRs and reduce latency.
- Improve Text Extraction (Screen Awareness) by capturing the entire active window node instead of specific view IDs.

#### [MODIFY] `ActionService.dart` & `ToolDefinitions.dart`
- Enhance `_executeMcpWorkflow` to support generic UI elements (Buttons, TextFields, scrollable lists) rather than app-specific macros.
- Add automatic retries if accessibility action fails or if the target element isn't found on the first pass.

### Phase 3: Play Store Integration

#### [MODIFY] `ActionService.dart` (or new `AppInstallService.dart`)
- Implement a dedicated function to detect the Play Store package (`com.android.vending`).
- Construct specific intent URIs (`market://details?id=...` or `https://play.google.com/store/search?q=...`) to handle app not found and search automatically.
- Add a background task to monitor package installation broadcasts (`ACTION_PACKAGE_ADDED`).

### Phase 4: Performance & Background Stability (Accessibility & MediaProjection)

#### [MODIFY] `DevaAccessibilityService.kt`
- Move heavy view hierarchy parsing to a background coroutine or thread pool.
- Prevent duplicate events by implementing a debouncer for `TYPE_WINDOW_CONTENT_CHANGED` and `TYPE_WINDOW_STATE_CHANGED`.
- Fix memory leaks by clearing references to `AccessibilityNodeInfo` objects immediately after extraction.

#### [MODIFY] `SystemActionBridge.kt`
- Improve MediaProjection capture logic (if present) to reduce CPU/RAM usage.

### Phase 5: Logging, Error Recovery & Security

#### [NEW] `LoggerService.dart` / [MODIFY] Existing Service
- Implement a centralized logging system.
- Log Permission Statuses, Accessibility Events, MCP status, and errors with full stack traces.

#### [MODIFY] Flutter State Management
- Catch all module initialization exceptions.
- Implement a fallback mechanism that disables the faulty module and alerts the user, while keeping the rest of the application stable.
- Validate all intents to prevent `SecurityException` crashes.

### Phase 6: Code Quality & Final Validation

- Refactor large functions in `SettingsScreen.dart` and `ActionService.dart`.
- Ensure adherence to MVVM and Clean Architecture patterns where applicable.
- Conduct a complete audit of the project, generating a final report with detected bugs, root causes, and fixes applied.

## Verification Plan

### Automated Tests
- Run `flutter test` to ensure existing and new unit tests pass.

### Manual Verification
- **Permission Flow:** Navigate to Settings, request each permission, ensure the transition to Android Settings and back is seamless with no black screen.
- **MCP Test:** Trigger MCP on Chrome, WhatsApp, and Settings, verifying that `lastForegroundPackage` is detected correctly and text is parsed.
- **Play Store Test:** Request DEVA to install an uninstalled app and verify the flow.
- **Performance Test:** Monitor Android Studio Profiler for memory leaks and CPU spikes during active screen parsing.
