import 'package:flutter/material.dart';

import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../domain/entities/practice_mode_entity.dart';

/// Practice mode card widget.
///
/// Displays a practice mode with:
/// - Mode icon and name
/// - Success rate badge
/// - Difficulty indicator
/// - Proficiency/Mastery indicator (checkmark for 70%+, star for 80%+ with 5+ practices)
/// - Recommended badge (if applicable)
/// - Favorite indicator
class PracticeModeCard extends StatelessWidget {
  final PracticeModeEntity mode;
  final bool isRecommended;
  final bool isFirstRecommended;
  final VoidCallback onTap;
  final bool isTierLocked;
  final bool isUnlockLimitReached;

  const PracticeModeCard({
    super.key,
    required this.mode,
    this.isRecommended = false,
    this.isFirstRecommended = false,
    required this.onTap,
    this.isTierLocked = false,
    this.isUnlockLimitReached = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLocked = isTierLocked || isUnlockLimitReached;

    return Card(
      elevation: isRecommended ? 8 : 2,
      shadowColor: isRecommended
          ? theme.colorScheme.primary.withAlpha((0.5 * 255).round())
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isRecommended
            ? BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              )
            : BorderSide.none,
      ),
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with icon and proficiency/favorite indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Mode icon with optional proficiency overlay
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _getDifficultyColor()
                                  .withAlpha((0.1 * 255).round()),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              mode.icon,
                              color: _getDifficultyColor(),
                              size: 24,
                            ),
                          ),
                          // Proficiency/Mastery badge overlay
                          if (mode.isMastered)
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.colorScheme.surface,
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.star,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            )
                          else if (mode.isProficient)
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.colorScheme.surface,
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Favorite indicator
                      if (mode.isFavorite)
                        const Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Mode name
                  Text(
                    _getModeName(context, mode.modeType),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),

                  // Description with flexible spacing
                  Text(
                    _getModeDescription(context, mode.modeType),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Stats and badges
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // Success rate or proficiency badge
                      if (mode.timesPracticed > 0) _SuccessBadge(mode: mode),
                      // Difficulty badge
                      _DifficultyBadge(difficulty: mode.difficulty),
                    ],
                  ),

                  // Recommended badge
                  if (isRecommended) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.tr(isFirstRecommended
                                ? TranslationKeys
                                    .practiceSelectionMasterThisFirst
                                : TranslationKeys
                                    .practiceSelectionMasterThisNext),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Lock overlay for tier-locked or unlock-limit modes
          if (isLocked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha((0.7 * 255).round()),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isTierLocked ? Icons.lock : Icons.lock_clock,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isTierLocked ? 'Upgrade Required' : 'Daily Limit Reached',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isTierLocked
                          ? 'Tap to see plans'
                          : 'Choose unlocked modes',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getDifficultyColor() {
    switch (mode.difficulty) {
      case Difficulty.easy:
        return Colors.green;
      case Difficulty.medium:
        return Colors.orange;
      case Difficulty.hard:
        return Colors.red;
    }
  }

  /// Get translated mode name
  String _getModeName(BuildContext context, PracticeModeType modeType) {
    switch (modeType) {
      case PracticeModeType.flipCard:
        return context.tr(TranslationKeys.practiceModeFlipCard);
      case PracticeModeType.wordBank:
        return context.tr(TranslationKeys.practiceModeWordBank);
      case PracticeModeType.cloze:
        return context.tr(TranslationKeys.practiceModeCloze);
      case PracticeModeType.firstLetter:
        return context.tr(TranslationKeys.practiceModeFirstLetter);
      case PracticeModeType.progressive:
        return context.tr(TranslationKeys.practiceModeProgressive);
      case PracticeModeType.wordScramble:
        return context.tr(TranslationKeys.practiceModeWordScramble);
      case PracticeModeType.audio:
        return context.tr(TranslationKeys.practiceModeAudio);
      case PracticeModeType.typeItOut:
        return context.tr(TranslationKeys.practiceModeTypeItOut);
    }
  }

  /// Get translated mode description
  String _getModeDescription(BuildContext context, PracticeModeType modeType) {
    switch (modeType) {
      case PracticeModeType.flipCard:
        return context.tr(TranslationKeys.practiceModeFlipCardDesc);
      case PracticeModeType.wordBank:
        return context.tr(TranslationKeys.practiceModeWordBankDesc);
      case PracticeModeType.cloze:
        return context.tr(TranslationKeys.practiceModeClozeDesc);
      case PracticeModeType.firstLetter:
        return context.tr(TranslationKeys.practiceModeFirstLetterDesc);
      case PracticeModeType.progressive:
        return context.tr(TranslationKeys.practiceModeProgressiveDesc);
      case PracticeModeType.wordScramble:
        return context.tr(TranslationKeys.practiceModeWordScrambleDesc);
      case PracticeModeType.audio:
        return context.tr(TranslationKeys.practiceModeAudioDesc);
      case PracticeModeType.typeItOut:
        return context.tr(TranslationKeys.practiceModeTypeItOutDesc);
    }
  }
}

/// Success rate badge - shows Mastered/Proficient labels or percentage
class _SuccessBadge extends StatelessWidget {
  final PracticeModeEntity mode;

  const _SuccessBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getSuccessColor();
    final label = _getLabel(context);
    final icon = _getIcon();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getLabel(BuildContext context) {
    // Show "Mastered" if mastered (80%+ with 5+ practices)
    if (mode.isMastered) {
      return context.tr(TranslationKeys.practiceBadgeMastered);
    }
    // Show "Proficient" if proficient (70%+ with 3+ practices)
    if (mode.isProficient) {
      return context.tr(TranslationKeys.practiceBadgeProficient);
    }
    // Show percentage for those still learning
    return '${mode.successRate.toStringAsFixed(0)}%';
  }

  IconData _getIcon() {
    if (mode.isMastered) {
      return Icons.star;
    }
    if (mode.isProficient) {
      return Icons.check_circle;
    }
    // Learning: show trending up if improving, circle otherwise
    if (mode.successRate >= PracticeModeProgression.proficiencyThreshold) {
      return Icons.trending_up;
    }
    return Icons.circle_outlined;
  }

  Color _getSuccessColor() {
    // Mastered = gold/amber, Proficient = green, Learning = orange
    if (mode.isMastered) {
      return Colors.amber;
    }
    if (mode.isProficient) {
      return Colors.green;
    }
    if (mode.successRate >= PracticeModeProgression.proficiencyThreshold) {
      return Colors.blue;
    }
    return Colors.orange;
  }
}

/// Difficulty badge
class _DifficultyBadge extends StatelessWidget {
  final Difficulty difficulty;

  const _DifficultyBadge({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getDifficultyColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        _getDifficultyLabel(context).toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getDifficultyLabel(BuildContext context) {
    switch (difficulty) {
      case Difficulty.easy:
        return context.tr(TranslationKeys.difficultyEasy);
      case Difficulty.medium:
        return context.tr(TranslationKeys.difficultyMedium);
      case Difficulty.hard:
        return context.tr(TranslationKeys.difficultyHard);
    }
  }

  Color _getDifficultyColor() {
    switch (difficulty) {
      case Difficulty.easy:
        return Colors.green;
      case Difficulty.medium:
        return Colors.orange;
      case Difficulty.hard:
        return Colors.red;
    }
  }
}
