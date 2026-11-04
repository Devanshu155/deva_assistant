/// DevaAvatar — the main avatar orchestrator.
/// Composes glow + particles + rings + orb in a layered stack.
/// This widget is the visual soul of DEVA.
library;

import 'package:flutter/material.dart';
import 'avatar_glow.dart';
import 'avatar_orb.dart';
import 'avatar_particles.dart';
import 'avatar_rings.dart';
import '../../../../../features/assistant/data/models/assistant_state.dart';
import '../../../../../core/theme/app_colors.dart';

class DevaAvatar extends StatelessWidget {
  final AssistantState assistantState;
  final VoidCallback? onTap;
  final double size;

  const DevaAvatar({
    super.key,
    required this.assistantState,
    this.onTap,
    this.size = 220,
  });

  @override
  Widget build(BuildContext context) {
    final state = assistantState.status;
    // The canvas is 3× the orb size to fit rings + particles + glow
    final canvasSize = size * 3;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: canvasSize,
        height: canvasSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Layer 1: Background glow (widest, behind everything)
            Positioned.fill(child: AvatarGlow(state: state)),

            // Layer 2: Outer particles (orbit freely)
            Positioned.fill(
              child: AvatarParticles(state: state, orbSize: size),
            ),

            // Layer 3: Rotating rings (between particles and orb)
            Positioned.fill(
              child: AvatarRings(state: state, orbSize: size),
            ),

            // Layer 4: Core orb (center)
            AvatarOrb(state: state, size: size),

            // Layer 5: State icon overlay (listening = mic icon, etc.)
            _StateIconOverlay(state: state, orbSize: size),
          ],
        ),
      ),
    );
  }
}

/// Subtle icon overlay on the orb — e.g., waveform for listening.
class _StateIconOverlay extends StatefulWidget {
  final DevaState state;
  final double orbSize;
  const _StateIconOverlay({required this.state, required this.orbSize});

  @override
  State<_StateIconOverlay> createState() => _StateIconOverlayState();
}

class _StateIconOverlayState extends State<_StateIconOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_StateIconOverlay old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  IconData? get _icon => switch (widget.state) {
        DevaState.listening => Icons.graphic_eq_rounded,
        DevaState.processing => Icons.auto_awesome_rounded,
        DevaState.error => Icons.error_outline_rounded,
        DevaState.success => Icons.check_circle_outline_rounded,
        _ => null,
      };

  Color get _color => AppColors.glowColorFor(widget.state.colorKey);

  @override
  Widget build(BuildContext context) {
    final icon = _icon;
    if (icon == null) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fade,
      child: Icon(
        icon,
        size: widget.orbSize * 0.35,
        color: _color.withValues(alpha: 0.9),
        shadows: [
          Shadow(color: _color, blurRadius: 20),
        ],
      ),
    );
  }
}
