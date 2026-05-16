/// Avatar glow — pulsing radial background glow behind the orb.
/// Intensity and color changes with DevaState.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../features/assistant/data/models/assistant_state.dart';

class AvatarGlow extends StatefulWidget {
  final DevaState state;
  const AvatarGlow({super.key, required this.state});

  @override
  State<AvatarGlow> createState() => _AvatarGlowState();
}

class _AvatarGlowState extends State<AvatarGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AvatarGlow old) {
    super.didUpdateWidget(old);
    // Speed up during active states
    final fast = widget.state == DevaState.processing ||
                 widget.state == DevaState.listening;
    _ctrl.duration = Duration(milliseconds: fast ? 800 : 2200);
    if (!_ctrl.isAnimating) _ctrl.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.glowColorFor(widget.state.colorKey);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => CustomPaint(
        painter: _GlowPainter(
          color: color,
          intensity: _pulse.value,
          stateIndex: widget.state.index,
        ),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  final Color color;
  final double intensity;
  final int stateIndex;

  const _GlowPainter({
    required this.color,
    required this.intensity,
    required this.stateIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) * 0.65;

    // Outer soft glow
    final outerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.15 * intensity),
          color.withOpacity(0.05 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius, outerPaint);

    // Inner brighter glow
    final innerRadius = maxRadius * 0.5;
    final innerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.25 * intensity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: innerRadius));
    canvas.drawCircle(center, innerRadius, innerPaint);
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.intensity != intensity || old.color != color;
}
