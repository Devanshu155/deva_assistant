/// Avatar particles — orbital particle system reacting to DEVA state.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../features/assistant/data/models/assistant_state.dart';

class AvatarParticles extends StatefulWidget {
  final DevaState state;
  final double orbSize;
  const AvatarParticles(
      {super.key, required this.state, required this.orbSize});

  @override
  State<AvatarParticles> createState() => _AvatarParticlesState();
}

class _AvatarParticlesState extends State<AvatarParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Particle> _particles;
  final _rand = math.Random();

  @override
  void initState() {
    super.initState();
    _spawnParticles();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  void _spawnParticles() {
    final count = _particleCount(widget.state);
    _particles = List.generate(count, (i) => _Particle.random(_rand, i, count));
  }

  int _particleCount(DevaState s) => switch (s) {
        DevaState.idle => 12,
        DevaState.greeting => 20,
        DevaState.listening => 22,
        DevaState.processing => 30,
        DevaState.speaking => 18,
        DevaState.success => 35,
        DevaState.error => 8,
      };

  @override
  void didUpdateWidget(AvatarParticles old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      _spawnParticles();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.glowColorFor(widget.state.colorKey);
    final orbitRadius = widget.orbSize / 2;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _ParticlesPainter(
          particles: _particles,
          color: color,
          time: _ctrl.value,
          orbitRadius: orbitRadius,
          state: widget.state,
        ),
      ),
    );
  }
}

class _Particle {
  final double orbitRadius; // Distance from center
  final double speed; // Orbit speed multiplier
  final double startAngle; // Initial angle
  final double size; // Dot size
  final double opacity;

  const _Particle({
    required this.orbitRadius,
    required this.speed,
    required this.startAngle,
    required this.size,
    required this.opacity,
  });

  factory _Particle.random(math.Random rand, int index, int total) {
    final baseAngle = (index / total) * 2 * math.pi;
    return _Particle(
      orbitRadius: 1.1 + rand.nextDouble() * 1.2, // 1.1x–2.3x orb radius
      speed: 0.3 + rand.nextDouble() * 0.7,
      startAngle: baseAngle + (rand.nextDouble() - 0.5) * 0.5,
      size: 1.5 + rand.nextDouble() * 2.5,
      opacity: 0.3 + rand.nextDouble() * 0.6,
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final Color color;
  final double time;
  final double orbitRadius;
  final DevaState state;

  const _ParticlesPainter({
    required this.particles,
    required this.color,
    required this.time,
    required this.orbitRadius,
    required this.state,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final speedMult = switch (state) {
      DevaState.processing => 2.5,
      DevaState.listening => 1.8,
      DevaState.speaking => 1.3,
      DevaState.greeting => 1.6,
      DevaState.success => 3.0,
      _ => 1.0,
    };

    for (final p in particles) {
      final angle = p.startAngle + time * p.speed * speedMult * 2 * math.pi;
      final r = p.orbitRadius * orbitRadius;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle) * 0.7; // squish for 3D

      final paint = Paint()
        ..color = color.withValues(alpha: p.opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

      canvas.drawCircle(Offset(x, y), p.size / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter old) =>
      old.time != time || old.color != color || old.state != state;
}
