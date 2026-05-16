/// Avatar orb — the core animated orb at the center of DEVA's UI.
/// Uses CustomPainter with radial gradients, inner glow, and shimmer.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../features/assistant/data/models/assistant_state.dart';

class AvatarOrb extends StatefulWidget {
  final DevaState state;
  final double size;
  const AvatarOrb({super.key, required this.state, this.size = 200});

  @override
  State<AvatarOrb> createState() => _AvatarOrbState();
}

class _AvatarOrbState extends State<AvatarOrb>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _rotateCtrl;
  late AnimationController _shakeCtrl;
  late Animation<double> _scale;
  late Animation<double> _rotation;
  late Animation<double> _shakeX;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _rotation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      _rotateCtrl,
    );

    _shakeX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12, end: 12), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12, end: -8),  weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8,  end: 8),  weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8,   end: 0),  weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _updateForState(widget.state);
  }

  @override
  void didUpdateWidget(AvatarOrb old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      _updateForState(widget.state);
    }
  }

  void _updateForState(DevaState s) {
    switch (s) {
      case DevaState.idle:
        _pulseCtrl.duration = const Duration(milliseconds: 2800);
        _rotateCtrl.duration = const Duration(seconds: 12);
        _scale = Tween<double>(begin: 0.96, end: 1.04).animate(
          CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
        break;
      case DevaState.greeting:
        _pulseCtrl.duration = const Duration(milliseconds: 1200);
        _scale = Tween<double>(begin: 0.9, end: 1.12).animate(
          CurvedAnimation(parent: _pulseCtrl, curve: Curves.elasticOut));
        break;
      case DevaState.listening:
        _pulseCtrl.duration = const Duration(milliseconds: 600);
        _rotateCtrl.duration = const Duration(seconds: 4);
        _scale = Tween<double>(begin: 0.98, end: 1.08).animate(
          CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
        break;
      case DevaState.processing:
        _pulseCtrl.duration = const Duration(milliseconds: 400);
        _rotateCtrl.duration = const Duration(seconds: 2);
        _scale = Tween<double>(begin: 1.0, end: 1.06).animate(
          CurvedAnimation(parent: _pulseCtrl, curve: Curves.linear));
        break;
      case DevaState.speaking:
        _pulseCtrl.duration = const Duration(milliseconds: 800);
        _rotateCtrl.duration = const Duration(seconds: 6);
        _scale = Tween<double>(begin: 0.97, end: 1.07).animate(
          CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
        break;
      case DevaState.success:
        _pulseCtrl.duration = const Duration(milliseconds: 500);
        _scale = Tween<double>(begin: 1.0, end: 1.15).animate(
          CurvedAnimation(parent: _pulseCtrl, curve: Curves.bounceOut));
        break;
      case DevaState.error:
        _shakeCtrl.forward(from: 0);
        break;
    }
    if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true);
    if (!_rotateCtrl.isAnimating) _rotateCtrl.repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = AppColors.orbGradientFor(widget.state.colorKey);
    final glowColor = AppColors.glowColorFor(widget.state.colorKey);

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseCtrl, _rotateCtrl, _shakeCtrl]),
      builder: (_, __) {
        return Transform.translate(
          offset: Offset(_shakeX.value, 0),
          child: Transform.scale(
            scale: _scale.value,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _OrbPainter(
                  gradient: gradient,
                  glowColor: glowColor,
                  rotation: _rotation.value,
                  pulseValue: _pulseCtrl.value,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  final RadialGradient gradient;
  final Color glowColor;
  final double rotation;
  final double pulseValue;

  const _OrbPainter({
    required this.gradient,
    required this.glowColor,
    required this.rotation,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // ── Outer glow ring ───────────────────────────────────────────────
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          glowColor.withOpacity(0.0),
          glowColor.withOpacity(0.12 + 0.08 * pulseValue),
          glowColor.withOpacity(0.0),
        ],
        stops: const [0.55, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.3));
    canvas.drawCircle(center, radius * 1.3, glowPaint);

    // ── Core orb ──────────────────────────────────────────────────────
    final orbPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, orbPaint);

    // ── Inner shimmer highlight ───────────────────────────────────────
    final shimmerCenter = Offset(
      center.dx - radius * 0.25 * math.cos(rotation),
      center.dy - radius * 0.25 * math.sin(rotation),
    );
    final shimmerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.3 + 0.1 * pulseValue),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: shimmerCenter, radius: radius * 0.4),
      );
    canvas.drawCircle(shimmerCenter, radius * 0.4, shimmerPaint);

    // ── Surface rim ───────────────────────────────────────────────────
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = glowColor.withOpacity(0.4 + 0.2 * pulseValue)
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center, radius - 1, rimPaint);
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.rotation != rotation || old.pulseValue != pulseValue ||
      old.glowColor != glowColor;
}
