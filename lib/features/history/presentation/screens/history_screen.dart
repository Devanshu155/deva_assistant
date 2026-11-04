/// History screen — locally stored command history, never leaves device.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../../../../shared/database/history_dao.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

final historyProvider = FutureProvider<List<HistoryEntry>>((ref) async {
  return HistoryDao.instance.getAll();
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('History',
            style: AppTypography.headingSmall.copyWith(letterSpacing: 2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded,
                color: AppColors.redError),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  title: Text('Clear all history?',
                      style: AppTypography.headingSmall),
                  content: Text('This cannot be undone.',
                      style: AppTypography.bodyMedium),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear',
                            style: TextStyle(color: AppColors.redError))),
                  ],
                ),
              );
              if (ok == true) {
                await HistoryDao.instance.clearAll();
                ref.invalidate(historyProvider);
              }
            },
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.cyanPrimary)),
        error: (e, _) =>
            Center(child: Text('Error: $e', style: AppTypography.bodyMedium)),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_rounded,
                        size: 64,
                        color: AppColors.textHint.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    Text('No history yet',
                        style: AppTypography.headingSmall
                            .copyWith(color: AppColors.textHint)),
                    const SizedBox(height: 8),
                    Text('Talk to DEVA to see history here.',
                        style: AppTypography.bodyMedium,
                        textAlign: TextAlign.center),
                  ]),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: entries.length,
            itemBuilder: (ctx, i) {
              final e = entries[i];
              final dateStr = DateFormat('d MMM, HH:mm').format(e.createdAt);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.glassWhite,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: AppColors.glassBorder, width: 0.5),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.cyanPrimary.withValues(alpha: 0.1),
                            border: Border.all(
                                color: AppColors.cyanPrimary
                                    .withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.person_rounded,
                              color: AppColors.cyanPrimary, size: 18),
                        ),
                        title: Text(e.userText,
                            style: AppTypography.bodyLarge.copyWith(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.auto_awesome_rounded,
                                    size: 12, color: AppColors.cyanPrimary),
                                const SizedBox(width: 4),
                                Expanded(
                                    child: Text(e.aiResponse,
                                        style: AppTypography.bodyMedium
                                            .copyWith(fontSize: 12),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis)),
                              ]),
                              const SizedBox(height: 6),
                              Row(children: [
                                if (e.toolUsed != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.purpleAccent
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: AppColors.purpleAccent
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                        e.toolUsed!
                                            .replaceAll('_', ' ')
                                            .toUpperCase(),
                                        style: AppTypography.labelMedium
                                            .copyWith(
                                                color: AppColors.purpleAccent,
                                                fontSize: 9,
                                                letterSpacing: 1)),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(dateStr, style: AppTypography.bodySmall),
                              ]),
                            ]),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 16, color: AppColors.textHint),
                          onPressed: () async {
                            await HistoryDao.instance.deleteById(e.id);
                            ref.invalidate(historyProvider);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
