/// Main assistant screen — full-screen avatar with no text input.
/// DEVA auto-activates on open: greeting → auto-listen → conversation loop.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/assistant_provider.dart';
import '../widgets/avatar/deva_avatar.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../features/assistant/data/models/assistant_state.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(assistantProvider.notifier);
    if (state == AppLifecycleState.paused) {
      notifier.pause();
    } else if (state == AppLifecycleState.resumed) {
      notifier.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      // No AppBar — pure immersive experience
      body: Stack(
        children: [
          // ── Background gradient ──────────────────────────────────────
          _BackgroundCanvas(state: state.status),

          // ── DEVA logo / name ─────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 24,
            left: 0,
            right: 0,
            child: _AppTitle(isOffline: state.isOffline),
          ),

          // ── Centered avatar ──────────────────────────────────────────
          Center(
            child: DevaAvatar(
              assistantState: state,
              size: size.width * 0.52,
              onTap: () =>
                  ref.read(assistantProvider.notifier).onAvatarTapped(),
            ),
          ),

          // ── Status label (LISTENING / THINKING / etc.) ────────────────
          Positioned(
            bottom: size.height * 0.22,
            left: 0,
            right: 0,
            child: _StatusLabel(state: state),
          ),

          // ── Transcript / response overlay ────────────────────────────
          Positioned(
            bottom: size.height * 0.10,
            left: 32,
            right: 32,
            child: _TranscriptOverlay(state: state),
          ),

          // ── Offline badge ─────────────────────────────────────────────
          if (state.isOffline)
            Positioned(
              top: MediaQuery.of(context).padding.top + 64,
              left: 0,
              right: 0,
              child: const _OfflineBadge(),
            ),
        ],
      ),
    );
  }
}

// ── Background canvas ──────────────────────────────────────────────────────

class _BackgroundCanvas extends StatelessWidget {
  final DevaState state;
  const _BackgroundCanvas({required this.state});

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.glowColorFor(state.colorKey);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 1.2,
          colors: [
            accent.withValues(alpha: 0.07),
            AppColors.background,
          ],
        ),
      ),
    );
  }
}

// ── App title ──────────────────────────────────────────────────────────────

class _AppTitle extends StatelessWidget {
  final bool isOffline;
  const _AppTitle({required this.isOffline});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'DEVA',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.cyanPrimary,
            letterSpacing: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'AI ASSISTANT',
          textAlign: TextAlign.center,
          style: AppTypography.neonLabel.copyWith(
            fontSize: 10,
            letterSpacing: 4,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }
}

// ── Status label ───────────────────────────────────────────────────────────

class _StatusLabel extends StatelessWidget {
  final AssistantState state;
  const _StatusLabel({required this.state});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Text(
        state.status.label,
        key: ValueKey(state.status),
        textAlign: TextAlign.center,
        style: AppTypography.neonLabel.copyWith(
          color: AppColors.glowColorFor(state.status.colorKey)
              .withValues(alpha: 0.85),
          letterSpacing: 4,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ── Transcript / response overlay ─────────────────────────────────────────

class _TranscriptOverlay extends StatelessWidget {
  final AssistantState state;
  const _TranscriptOverlay({required this.state});

  String get _displayText {
    if (state.partialTranscript.isNotEmpty) return state.partialTranscript;
    if (state.status == DevaState.speaking && state.lastAiResponse.isNotEmpty) {
      return state.lastAiResponse;
    }
    if (state.status == DevaState.error && state.errorMessage != null) {
      return state.errorMessage!;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final text = _displayText;
    if (text.isEmpty) return const SizedBox.shrink();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: text.isNotEmpty ? 1.0 : 0.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.glassWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.transcriptText,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ── Offline badge ──────────────────────────────────────────────────────────

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.redError.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.redError.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 13, color: AppColors.redError),
            const SizedBox(width: 6),
            Text(
              'OFFLINE',
              style: AppTypography.neonLabel.copyWith(
                color: AppColors.redError,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
