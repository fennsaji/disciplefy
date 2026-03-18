import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/ui_utils.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/daily_verse_entity.dart';
import '../../domain/entities/daily_verse_streak.dart';
import '../../../memory_verses/presentation/bloc/memory_verse_bloc.dart';
import '../../../memory_verses/presentation/bloc/memory_verse_event.dart';
import '../../../memory_verses/presentation/bloc/memory_verse_state.dart';
import '../../../tokens/presentation/bloc/token_bloc.dart';
import '../../../tokens/presentation/bloc/token_state.dart';
import '../../../tokens/domain/entities/token_status.dart';
import '../../../../core/widgets/upgrade_dialog.dart';
import '../../../../core/services/system_config_service.dart';
import '../bloc/daily_verse_bloc.dart';
import '../bloc/daily_verse_event.dart';
import '../bloc/daily_verse_state.dart';
import '../../../gamification/presentation/bloc/gamification_bloc.dart';
import '../../../gamification/presentation/bloc/gamification_event.dart';

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
    return BlocBuilder<DailyVerseBloc, DailyVerseState>(
      builder: (context, state) => Container(
        margin: margin ?? const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: _buildCardContent(context, state),
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book,
                color: Colors.white.withOpacity(0.9),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isRefreshing
                      ? context.tr(TranslationKeys.dailyVerseRefreshing)
                      : context.tr(TranslationKeys.dailyVerseLoading),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            valueColor:
                AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.8)),
            backgroundColor: Colors.white.withOpacity(0.2),
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
              // Header with date
              _buildHeader(
                context,
                state.formattedDate,
                state.isFromCache,
                streak: state.streak,
              ),

              const SizedBox(height: 16),

              // Verse reference
              Text(
                state.verse.getReferenceText(state.currentLanguage),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 12),

              // Verse text
              Text(
                state.currentVerseText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.95),
                  height: 1.7,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.start,
              ),

              if (onTap != null && !isDisabled) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        context.tr(TranslationKeys.dailyVerseTapToGenerate),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // Action buttons
              _buildActionButtons(context, state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineState(BuildContext context, DailyVerseOffline state) {
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
                color: Colors.amber[300],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                context.tr(TranslationKeys.dailyVerseOfflineMode),
                style: TextStyle(
                  color: Colors.amber[300],
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                state.formattedDate,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Verse reference
          Text(
            state.verse.getReferenceText(state.currentLanguage),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 8),

          // Verse text
          Text(
            state.currentVerseText,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.9),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, DailyVerseError state) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.amber[300],
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            context.tr(TranslationKeys.dailyVerseUnableToLoad),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(TranslationKeys.dailyVerseSomethingWentWrong),
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  context.read<DailyVerseBloc>().add(const RefreshVerse());
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        context.tr(TranslationKeys.homeTryAgain),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
    // Use white colors on the purple gradient background
    const textColor = Colors.white;
    final subtleTextColor = Colors.white.withOpacity(0.8);

    return Row(
      children: [
        Icon(
          Icons.menu_book,
          color: textColor.withOpacity(0.9),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      fontSize: 16,
                    ),
                  ),
                  if (onTap != null && !isDisabled) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.touch_app,
                      size: 16,
                      color: subtleTextColor,
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
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt,
                            size: 14,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${streak.currentStreak}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
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
                style: TextStyle(
                  color: subtleTextColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (isFromCache)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              context.tr(TranslationKeys.dailyVerseCached),
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: textColor,
                fontSize: 11,
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
    // White icons on purple gradient background
    const iconColor = Colors.white;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Copy button
        IconButton(
          onPressed: () => _copyVerseToClipboard(context, state),
          icon: const Icon(
            Icons.copy_outlined,
            color: iconColor,
            size: 22,
          ),
          tooltip: context.tr(TranslationKeys.dailyVerseCopy),
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.all(10),
          ),
        ),

        const SizedBox(width: 8),

        // Share button
        IconButton(
          onPressed: () => _shareVerse(state),
          icon: const Icon(
            Icons.share_outlined,
            color: iconColor,
            size: 22,
          ),
          tooltip: context.tr(TranslationKeys.dailyVerseShare),
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.all(10),
          ),
        ),

        const SizedBox(width: 8),

        // Add to Memory button
        _AddToMemoryButton(verseState: state),

        const SizedBox(width: 8),

        // Refresh button
        IconButton(
          onPressed: () {
            context.read<DailyVerseBloc>().add(const RefreshVerse());
          },
          icon: const Icon(
            Icons.refresh,
            color: iconColor,
            size: 22,
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
    // White shimmer placeholders on purple gradient
    return FractionallySizedBox(
      widthFactor: width,
      child: Container(
        height: 16,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
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
        backgroundColor: context.appInteractive,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareVerse(DailyVerseLoaded state) {
    final appLink = kIsWeb
        ? '🌐 https://app.disciplefy.in/'
        : Platform.isAndroid
            ? '📱 https://play.google.com/store/apps/details?id=com.disciplefy.bible_study'
            : '🌐 https://app.disciplefy.in/';
    final text =
        '${state.verse.getReferenceText(state.currentLanguage)}\n\n${state.currentVerseText}\n\n— Shared from Disciplefy: Bible Study App\n$appLink';
    Share.share(text);
  }
}

// ---------------------------------------------------------------------------
// _AddToMemoryButton
// ---------------------------------------------------------------------------

/// Self-contained button that adds the daily verse to the memory deck.
///
/// Uses local [_isLoading] state so the spinner appears **immediately** on tap,
/// without relying on BLoC state-transition timing.
class _AddToMemoryButton extends StatefulWidget {
  final DailyVerseLoaded verseState;

  const _AddToMemoryButton({required this.verseState});

  @override
  State<_AddToMemoryButton> createState() => _AddToMemoryButtonState();
}

class _AddToMemoryButtonState extends State<_AddToMemoryButton> {
  static const _iconColor = Colors.white;
  bool _isLoading = false;

  void _onTap() {
    final tokenState = sl<TokenBloc>().state;
    final userPlan = tokenState is TokenLoaded
        ? tokenState.tokenStatus.userPlan.name
        : 'free';

    final configService = sl<SystemConfigService>();
    if (!configService.isFeatureEnabled('memory_verses', userPlan)) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => UpgradeDialog(
          featureKey: 'memory_verses',
          currentPlan: userPlan,
          requiredPlans: configService.getRequiredPlans('memory_verses'),
          upgradePlan: configService.getUpgradePlan('memory_verses', userPlan),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final memoryVerseBloc = sl<MemoryVerseBloc>();
    memoryVerseBloc.add(AddVerseFromDaily(
      widget.verseState.verse.id,
      language: widget.verseState.currentLanguage.code,
    ));

    final subscription = memoryVerseBloc.stream.listen((state) {
      if (state is VerseAdded) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showAddedSnackBar();
          sl<GamificationBloc>().add(const CheckMemoryAchievements());
        }
      } else if (state is MemoryVerseError) {
        if (mounted) {
          setState(() => _isLoading = false);
          if (state.code == 'VERSE_ALREADY_EXISTS') {
            _showAlreadyExistsSnackBar();
          } else {
            _showErrorSnackBar();
          }
        }
      } else if (state is OperationQueued) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showQueuedSnackBar(state.message);
        }
      }
    });

    // Safety timeout — cancel listener and clear spinner after 10 s.
    Future.delayed(const Duration(seconds: 10), () {
      subscription.cancel();
      if (mounted && _isLoading) setState(() => _isLoading = false);
    });
  }

  void _showAddedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check_circle, color: Colors.white),
        SizedBox(width: 8),
        Expanded(
            child: Text(
                'Added to Memory Verses! Start reviewing to memorize this verse.')),
      ]),
      backgroundColor: AppColors.success,
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'Review Now',
        textColor: Colors.white,
        onPressed: () => GoRouter.of(context).go('/memory-verses'),
      ),
    ));
  }

  void _showErrorSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Something went wrong. Please try again.'),
      backgroundColor: AppColors.error,
      duration: Duration(seconds: 3),
    ));
  }

  void _showAlreadyExistsSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.bookmark, color: Colors.white),
        SizedBox(width: 8),
        Expanded(child: Text('Verse already in your memory deck')),
      ]),
      backgroundColor: AppColors.warning,
      action: SnackBarAction(
        label: 'Review',
        textColor: Colors.white,
        onPressed: () => GoRouter.of(context).go('/memory-verses'),
      ),
    ));
  }

  void _showQueuedSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.cloud_off, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: AppColors.warning,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_iconColor),
            ),
          ),
        ),
      );
    }

    return BlocBuilder<MemoryVerseBloc, MemoryVerseState>(
      bloc: sl<MemoryVerseBloc>(),
      builder: (context, memoryState) {
        final isAlreadyInMemory = memoryState is DueVersesLoaded &&
            memoryState.verses.any((v) =>
                v.sourceId == widget.verseState.verse.id &&
                v.language == widget.verseState.currentLanguage.code);

        return IconButton(
          onPressed: isAlreadyInMemory ? null : _onTap,
          icon: Icon(
            isAlreadyInMemory ? Icons.bookmark : Icons.bookmark_add_outlined,
            color: isAlreadyInMemory ? _iconColor.withOpacity(0.5) : _iconColor,
            size: 22,
          ),
          tooltip: isAlreadyInMemory
              ? context.tr(TranslationKeys.dailyVerseAlreadyInMemory)
              : context.tr(TranslationKeys.dailyVerseAddToMemory),
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.all(10),
          ),
        );
      },
    );
  }
}
