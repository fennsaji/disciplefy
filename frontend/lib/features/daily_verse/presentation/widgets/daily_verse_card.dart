import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/ui_utils.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../domain/entities/daily_verse_entity.dart';
import '../../domain/entities/daily_verse_streak.dart';
import '../bloc/daily_verse_bloc.dart';
import '../bloc/daily_verse_event.dart';
import '../bloc/daily_verse_state.dart';

/// Daily verse card widget for home screen
class DailyVerseCard extends StatelessWidget {
  final VoidCallback? onTap;
  final bool showLanguageTabs;
  final EdgeInsetsGeometry? margin;
  final bool isDisabled;

  const DailyVerseCard({
    super.key,
    this.onTap,
    this.showLanguageTabs = true,
    this.margin,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<DailyVerseBloc, DailyVerseState>(
      builder: (context, state) => Container(
        margin: margin ?? const EdgeInsets.symmetric(horizontal: 20),
        child: Card(
          elevation: 2,
          shadowColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              // Use secondary theme color (light gold) for consistent theming
              color: theme.colorScheme.secondary,
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
              ),
            ),
            child: _buildCardContent(context, state),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, DailyVerseState state) {
    if (state is DailyVerseLoading) {
      return _buildLoadingState(context, state.isRefreshing);
    } else if (state is DailyVerseLoaded) {
      return _buildLoadedState(context, state);
    } else if (state is DailyVerseOffline) {
      return _buildOfflineState(context, state);
    } else if (state is DailyVerseError) {
      return _buildErrorState(context, state);
    } else {
      return _buildEmptyState(context);
    }
  }

  Widget _buildLoadingState(BuildContext context, bool isRefreshing) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book,
                color: theme.colorScheme.onSecondary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isRefreshing
                      ? context.tr(TranslationKeys.dailyVerseRefreshing)
                      : context.tr(TranslationKeys.dailyVerseLoading),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            valueColor:
                AlwaysStoppedAnimation<Color>(theme.colorScheme.onSecondary),
            backgroundColor: theme.colorScheme.surface,
          ),
          const SizedBox(height: 16),
          _buildShimmerText(context),
          const SizedBox(height: 12),
          _buildShimmerText(context, width: 0.7),
          const SizedBox(height: 12),
          _buildShimmerText(context, width: 0.5),
        ],
      ),
    );
  }

  Widget _buildLoadedState(BuildContext context, DailyVerseLoaded state) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedOpacity(
        opacity: isDisabled ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with date - improved spacing
              _buildHeader(
                context,
                state.formattedDate,
                state.isFromCache,
                streak: state.streak,
              ),

              const SizedBox(height: 20),

              // Language tabs removed - language preference handled in settings

              // Verse reference with highlight color and better spacing
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  state.verse.getReferenceText(state.currentLanguage),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // Verse text with improved background and spacing
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.currentVerseText,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSecondary,
                        height: 1.7,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.start,
                    ),
                    if (onTap != null && !isDisabled) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: theme.colorScheme.onSecondary
                                .withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            context.tr(TranslationKeys.dailyVerseTapToGenerate),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSecondary
                                  .withValues(alpha: 0.6),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Action buttons with improved spacing
              _buildActionButtons(context, state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineState(BuildContext context, DailyVerseOffline state) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Offline indicator
          Row(
            children: [
              Icon(
                Icons.wifi_off,
                color: theme.colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                context.tr(TranslationKeys.dailyVerseOfflineMode),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                state.formattedDate,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Language tabs removed - language preference handled in settings

          // Verse content
          Text(
            state.verse.getReferenceText(state.currentLanguage),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 12),

          // Verse text with background for better readability
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.secondary.withValues(alpha: 0.6),
              ),
            ),
            child: Text(
              state.currentVerseText,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, DailyVerseError state) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.error,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            context.tr(TranslationKeys.dailyVerseUnableToLoad),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(TranslationKeys.dailyVerseSomethingWentWrong),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSecondary.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              context.read<DailyVerseBloc>().add(const RefreshVerse());
            },
            icon: const Icon(Icons.refresh),
            label: Text(context.tr(TranslationKeys.homeTryAgain)),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    // Trigger load if we're in initial state and no load has been triggered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DailyVerseBloc>().add(const LoadTodaysVerse());
    });
    return _buildLoadingState(context, false);
  }

  Widget _buildHeader(
    BuildContext context,
    String date,
    bool isFromCache, {
    DailyVerseStreak? streak,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          Icons.menu_book,
          color: theme.colorScheme.onSecondary,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    context.tr(TranslationKeys.dailyVerseOfTheDay),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSecondary,
                    ),
                  ),
                  if (onTap != null && !isDisabled) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.touch_app,
                      size: 16,
                      color:
                          theme.colorScheme.onSecondary.withValues(alpha: 0.7),
                    ),
                  ],
                  // Push streak to the right side
                  const Spacer(),
                  // Compact streak indicator
                  if (streak != null && streak.currentStreak > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${streak.currentStreak}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                date,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        if (isFromCache)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSecondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              context.tr(TranslationKeys.dailyVerseCached),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLanguageTabs(
      BuildContext context, VerseLanguage currentLanguage) {
    final theme = Theme.of(context);

    return Row(
      children: VerseLanguage.values.map((language) {
        final isSelected = language == currentLanguage;

        // Determine background and text colors for proper contrast
        final backgroundColor = isSelected
            ? theme.colorScheme.secondary
            : theme.colorScheme.surface;

        // Use explicit contrast colors to ensure visibility
        final textColor = isSelected
            ? theme.colorScheme.onSecondary
            : UiUtils.getContrastColor(backgroundColor);

        return Expanded(
          child: GestureDetector(
            onTap: () {
              context.read<DailyVerseBloc>().add(
                    ChangeVerseLanguage(language: language),
                  );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.secondary
                              .withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                language.displayName,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons(BuildContext context, DailyVerseLoaded state) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Copy button
        TextButton.icon(
          onPressed: () => _copyVerseToClipboard(context, state),
          icon: Icon(
            Icons.copy,
            size: 20,
            color: theme.colorScheme.onSecondary,
          ),
          label: Text(
            context.tr(TranslationKeys.dailyVerseCopy),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSecondary,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            minimumSize: const Size(0, 44),
          ),
        ),

        const SizedBox(width: 12),

        // Share button
        TextButton.icon(
          onPressed: () => _shareVerse(state),
          icon: Icon(
            Icons.share,
            size: 20,
            color: theme.colorScheme.onSecondary,
          ),
          label: Text(
            context.tr(TranslationKeys.dailyVerseShare),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSecondary,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            minimumSize: const Size(0, 44),
          ),
        ),

        const SizedBox(width: 12),

        // Refresh button
        IconButton(
          onPressed: () {
            context.read<DailyVerseBloc>().add(const RefreshVerse());
          },
          icon: Icon(
            Icons.refresh,
            color: theme.colorScheme.onSecondary,
            size: 24,
          ),
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.all(10),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerText(BuildContext context, {double width = 1.0}) {
    final theme = Theme.of(context);

    return Container(
      height: 16,
      width: double.infinity * width,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  void _copyVerseToClipboard(BuildContext context, DailyVerseLoaded state) {
    final text =
        '${state.verse.getReferenceText(state.currentLanguage)}\n\n${state.currentVerseText}';
    Clipboard.setData(ClipboardData(text: text));

    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(TranslationKeys.dailyVerseCopied),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onPrimary,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareVerse(DailyVerseLoaded state) {
    final text =
        '${state.verse.getReferenceText(state.currentLanguage)}\n\n${state.currentVerseText}\n\n- Shared from Disciplefy';
    Share.share(text);
  }
}
