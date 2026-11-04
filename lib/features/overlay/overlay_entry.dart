/// Overlay Entry Point — the floating DEVA mini-avatar UI.
/// This runs in a separate Flutter isolate drawn over other apps.
/// Entry: overlayMain() registered in main.dart via @pragma('vm:entry-point').
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../../core/theme/app_colors.dart';

/// The entry point called by flutter_overlay_window for the overlay UI.
/// Must be a top-level function annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _OverlayApp());
}

class _OverlayApp extends StatelessWidget {
  const _OverlayApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      theme: ThemeData(
        canvasColor: Colors.transparent,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const Scaffold(
        backgroundColor: Colors.transparent,
        body: OverlayWidget(),
      ),
    );
  }
}

/// The visible floating DEVA mini avatar shown over other apps.
class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  String _status = 'LISTENING';
  Color _color = AppColors.greenAccent;

  StreamSubscription? _msgSub;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the mini orb
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Listen for state updates sent from the main app
    _msgSub = FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map && mounted) {
        setState(() {
          _status = (data['status'] as String? ?? 'LISTENING').toUpperCase();
          _color = _colorForStatus(_status);
        });
      }
    });
  }

  Color _colorForStatus(String status) {
    switch (status) {
      case 'LISTENING':
        return AppColors.greenAccent;
      case 'THINKING':
        return AppColors.purpleAccent;
      case 'SPEAKING':
        return AppColors.cyanPrimary;
      case 'ERROR':
        return AppColors.redError;
      default:
        return AppColors.cyanPrimary;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _msgSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        // Tap to send "open_app" message back to main app
        onTap: () => FlutterOverlayWindow.shareData({'action': 'open_app'}),
        // Long-press to dismiss overlay
        onLongPress: () => FlutterOverlayWindow.closeOverlay(),
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.background.withValues(alpha: 0.92),
            border: Border.all(
              color: _color.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _color.withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) => Transform.scale(
              scale: _pulse.value,
              child: child,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mini orb
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _color,
                        _color.withValues(alpha: 0.4),
                        AppColors.background,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _color.withValues(alpha: 0.6),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Icon(
                    _iconForStatus(_status),
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                // Status label
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _status,
                    key: ValueKey(_status),
                    style: TextStyle(
                      color: _color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'DEVA',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 9,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                // Hint labels
                Text(
                  'Tap to open · Hold to close',
                  style: TextStyle(
                    color: AppColors.textHint.withValues(alpha: 0.5),
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForStatus(String status) {
    switch (status) {
      case 'LISTENING':
        return Icons.graphic_eq_rounded;
      case 'THINKING':
        return Icons.auto_awesome_rounded;
      case 'SPEAKING':
        return Icons.volume_up_rounded;
      case 'ERROR':
        return Icons.error_outline_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }
}
