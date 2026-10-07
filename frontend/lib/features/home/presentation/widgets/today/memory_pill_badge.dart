import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// Count shown on the header's Memory Verses pill, or null for no badge.
///
/// No badge until the user has saved a verse and one is due: an empty deck
/// never nags. A guest has no deck, so the caller passes zeros for a guest.
int? memoryBadgeCount({required int savedCount, required int dueCount}) {
  if (savedCount == 0 || dueCount == 0) return null;
  return dueCount;
}

/// Small gold pill with the number of verses due, placed on the corner of
/// the Memory Verses pill.
class MemoryPillBadge extends StatelessWidget {
  final int count;

  const MemoryPillBadge({super.key, required this.count});

  static const Key pillKey = Key('memory_pill_badge');

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        key: pillKey,
        height: 16,
        constraints: const BoxConstraints(minWidth: 16),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.brandGold,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1,
            color: ReaderPalette.ink,
          ),
        ),
      ),
    );
  }
}
