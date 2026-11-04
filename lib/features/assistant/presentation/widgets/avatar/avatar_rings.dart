/// Avatar rings — concentric animated rings orbiting the orb.
/// Rotation speed and opacity vary by state.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../features/assistant/data/models/assistant_state.dart';

class AvatarRings extends StatefulWidget {
  final DevaState state;
  final double orbSize;
  const AvatarRings({super.key, required this.state, required this.orbSize});

  @override
  State<AvatarRings> createState() => _AvatarRingsState();
}

class _AvatarRingsState extends State<AvatarRings>
    with TickerProviderStateMixin {
  late AnimationController _ring1;
  late AnimationController _ring2;
  late AnimationController _ring3;

  @override
  void initState() {
    super.initState();
    _ring1 =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat();
    _ring2 =
        AnimationController(vsync: this, duration: const Duration(seconds: 9))
          ..repeat();
    _ring3 =
        AnimationController(vsync: this, duration: const Duration(seconds: 14))
          ..repeat();
    _updateSpeeds();
  }

  @override
  void didUpdateWidget(AvatarRings old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _updateSpeeds();
  }

  void _updateSpeeds() {
    final multiplier = switch (widget.state) {
      DevaState.processing => 3.0,
      DevaState.listening => 2.0,
      DevaState.speaking => 1.5,
      DevaState.greeting => 1.8,
      _ => 1.0,
    };
    _ring1.duration = Duration(milliseconds: (6000 / multiplier).round());
    _ring2.duration = Duration(milliseconds: (9000 / multiplier).round());
    _ring3.duration = Duration(milliseconds: (14000 / multiplier).round());
    for (final c in [_ring1, _ring2, _ring3]) {
      if (!c.isAnimating) c.repeat();
    }
  }

  @override
  void dispose() {
    _ring1.dispose();
    _ring2.dispose();
    _ring3.dispose();
    super.dispose();
  }

  double get _opacity {
    return switch (widget.state) {
      DevaState.idle => 0.3,
      DevaState.greeting => 0.7,
      DevaState.listening => 0.8,
      DevaState.processing => 0.9,
      DevaState.speaking => 0.6,
      DevaState.success => 0.9,
      DevaState.error => 0.4,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.glowColorFor(widget.state.colorKey);
    final halfOrb = widget.orbSize / 2;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 600),
      opacity: _opacity,
      child: AnimatedBuilder(
        animation: Listenable.merge([_ring1, _ring2, _ring3]),
        builder: (_, __) => CustomPaint(
          painter: _RingsPainter(
            color: color,
            orbRadius: halfOrb,
            angle1: _ring1.value * 2 * math.pi,
            angle2: -_ring2.value * 2 * math.pi,
            angle3: _ring3.value * 2 * math.pi,
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  final Color color;
  final double orbRadius;
  final double angle1;
  final double angle2;
  final double angle3;

  const _RingsPainter({
    required this.color,
    required this.orbRadius,
    required this.angle1,
    required this.angle2,
    required this.angle3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw 3 elliptical rings at different tilt angles
    _drawRing(canvas, center, orbRadius * 1.35, angle1, color, 1.2, 0.35);
    _drawRing(canvas, center, orbRadius * 1.65, angle2, color, 0.9, 0.25);
    _drawRing(canvas, center, orbRadius * 2.00, angle3, color, 0.6, 0.18);
  }

  void _drawRing(
    Canvas canvas,
    Offset center,
    double radius,
    double tilt,
    Color color,
    double strokeWidth,
    double opacity,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = strokeWidth
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    // Save/restore to apply tilt transformation
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt * 0.3);

    // Draw slightly elliptical ring (gives 3D depth illusion)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2,
        height: radius * 1.3,
      ),
      paint,
    );

    // Draw a bright dot on the ring to indicate rotation
    final dotAngle = tilt;
    final dotX = radius * math.cos(dotAngle);
    final dotY = radius * 0.65 * math.sin(dotAngle);
    canvas.drawCircle(
      Offset(dotX, dotY),
      1.5,
      Paint()..color = color.withValues(alpha: 0.8),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.angle1 != angle1 || old.color != color;
}
