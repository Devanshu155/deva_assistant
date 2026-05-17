/// Overlay Service — manages the floating DEVA avatar overlay (Phase 2.3).
/// Uses flutter_overlay_window to draw over other apps via SYSTEM_ALERT_WINDOW.
/// Called when wake word is detected while the app is in the background.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
  OverlayService._();
  static final OverlayService instance = OverlayService._();

  bool _hasPermission = false;

  // ── Permission ────────────────────────────────────────────────────────

  /// Check if SYSTEM_ALERT_WINDOW permission is granted.
  Future<bool> checkPermission() async {
    _hasPermission = await FlutterOverlayWindow.isPermissionGranted();
    return _hasPermission;
  }

  /// Request SYSTEM_ALERT_WINDOW permission from the user.
  /// Opens Android's "Draw Over Other Apps" settings screen.
  Future<bool> requestPermission() async {
    final granted = await FlutterOverlayWindow.requestPermission();
    _hasPermission = granted ?? false;
    return _hasPermission;
  }

  // ── Overlay control ───────────────────────────────────────────────────

  /// Show the floating DEVA avatar overlay.
  /// Call this when wake word is detected and the app is in the background.
  Future<void> showOverlay() async {
    if (!_hasPermission) {
      debugPrint('[Overlay] No permission — cannot show overlay.');
      return;
    }
    if (await FlutterOverlayWindow.isActive()) return; // already showing

    await FlutterOverlayWindow.showOverlay(
      height: 260,
      width: 260,
      alignment: OverlayAlignment.center,
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      enableDrag: true,
    );

    debugPrint('[Overlay] Floating DEVA avatar shown.');
  }

  /// Hide the floating overlay.
  /// Call this when the user opens the full app or dismisses the overlay.
  Future<void> hideOverlay() async {
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
      debugPrint('[Overlay] Overlay hidden.');
    }
  }

  /// Whether the overlay is currently visible.
  Future<bool> get isActive => FlutterOverlayWindow.isActive();

  // ── Communication ─────────────────────────────────────────────────────

  /// Send data from the main app to the overlay widget.
  Future<void> sendToOverlay(Map<String, dynamic> data) async {
    await FlutterOverlayWindow.shareData(data);
  }

  /// Stream of messages received FROM the overlay widget back to the main app.
  Stream<dynamic> get overlayMessages =>
      FlutterOverlayWindow.overlayListener;
}
