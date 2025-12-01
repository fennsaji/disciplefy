import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/auth_protected_screen.dart';
import '../../../daily_verse/domain/entities/daily_verse_entity.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_bloc.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_state.dart';
import '../../../notifications/presentation/widgets/notification_enable_prompt.dart';
import '../../domain/entities/memory_verse_entity.dart';
import '../bloc/memory_verse_bloc.dart';
import '../bloc/memory_verse_event.dart';
import '../bloc/memory_verse_state.dart';
import '../widgets/add_manual_verse_dialog.dart';
import '../widgets/add_verse_options_sheet.dart';
import '../widgets/memory_verse_list_item.dart';
import '../widgets/options_menu_sheet.dart';
import '../widgets/statistics_card.dart';
import '../widgets/statistics_dialog.dart';

class MemoryVersesHomePage extends StatefulWidget {
  const MemoryVersesHomePage({super.key});

  @override
  State<MemoryVersesHomePage> createState() => _MemoryVersesHomePageState();
}

class _MemoryVersesHomePageState extends State<MemoryVersesHomePage> {
  DueVersesLoaded? _lastLoadedState;
  VerseLanguage? _selectedLanguageFilter;
  bool _hasTriggeredMemoryVersePrompt = false;

  @override
  void initState() {
    super.initState();
    _loadVerses();
  }

  void _loadVerses({bool forceRefresh = false}) {
    context.read<MemoryVerseBloc>().add(LoadDueVerses(
          language: _selectedLanguageFilter?.code,
          forceRefresh: forceRefresh,
        ));
  }

  /// Shows the memory verse reminder notification prompt (once per session)
  Future<void> _showMemoryVerseReminderPrompt() async {
    if (_hasTriggeredMemoryVersePrompt) return;
    _hasTriggeredMemoryVersePrompt = true;

    // Small delay to let the snackbar show first
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final languageCode = context.translationService.currentLanguage.code;
    await showNotificationEnablePrompt(
      context: context,
      type: NotificationPromptType.memoryVerseReminder,
      languageCode: languageCode,
    );
  }

  /// Handle back navigation - go to home when can't pop
  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
    } else {
      GoRouter.of(context).goToHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            onPressed: _handleBackNavigation,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: AppTheme.primaryColor,
                size: 18,
              ),
            ),
          ),
          title: Text(
            context.tr(TranslationKeys.memoryTitle),
            style: AppFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          centerTitle: true,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.secondaryPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                onPressed: () => _showAddVerseOptions(context),
                tooltip: 'Add verse',
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.more_vert,
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
              ),
              onPressed: () => _showOptionsMenu(context),
              tooltip: 'Options',
            ),
          ],
        ),
        body: BlocConsumer<MemoryVerseBloc, MemoryVerseState>(
          listener: (context, state) {
            if (state is MemoryVerseError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                  action: SnackBarAction(
                    label: 'Retry',
                    textColor: Colors.white,
                    onPressed: _loadVerses,
                  ),
                ),
              );
            } else if (state is VerseAdded) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
              _loadVerses();
              // Show notification prompt for memory verse reminder after adding first verse
              _showMemoryVerseReminderPrompt();
            } else if (state is OperationQueued) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(child: Text(state.message)),
                    ],
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            } else if (state is VerseDeleted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text(context.tr(TranslationKeys.memoryDeleteSuccess)),
                  backgroundColor: Colors.green,
                ),
              );
              _loadVerses();
            }
          },
          builder: (context, state) {
            if (state is DueVersesLoaded) {
              _lastLoadedState = state;
            }
            if (state is MemoryVerseInitial) {
              return _buildLoadingState();
            }
            if (state is MemoryVerseLoading && !state.isRefreshing) {
              return _buildLoadingState();
            }
            if (state is MemoryVerseLoading && state.isRefreshing) {
              if (_lastLoadedState != null) {
                return _buildLoadedState(_lastLoadedState!);
              }
              return _buildLoadingState();
            }
            if (state is DueVersesLoaded) {
              return _buildLoadedState(state);
            }
            return _buildEmptyState();
          },
        ),
      ),
    ).withAuthProtection();
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading your verses...'),
        ],
      ),
    );
  }

  Widget _buildLoadedState(DueVersesLoaded state) {
    // Show full empty state only when user has no verses at all
    if (state.statistics.totalVerses == 0) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        _loadVerses(forceRefresh: true);
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(TranslationKeys.memoryYourProgress),
                    style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StatisticsCard(statistics: state.statistics),
                  const SizedBox(height: 16),
                  // Review All button - only show when there are due verses
                  if (state.verses.isNotEmpty)
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.secondaryPurple
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _startReviewAll(context, state.verses),
                          borderRadius: BorderRadius.circular(14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${context.tr(TranslationKeys.memoryReviewAll)} (${state.verses.length})',
                                style: AppFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _buildLanguageFilter(context),
                  const SizedBox(height: 16),
                  Text(
                    '${context.tr(TranslationKeys.memoryDueForReview)} (${state.verses.length})',
                    style: AppFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                  if (state.statistics.dueVerses > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      _getVersesToReviewMessage(
                          context, state.statistics.dueVerses),
                      style: AppFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Show verses list or empty filter message
          if (state.verses.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final verse = state.verses[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: MemoryVerseListItem(
                        verse: verse,
                        onTap: () => _navigateToReviewPage(context, verse.id),
                        onDelete: () => _showDeleteConfirmation(context, verse),
                      ),
                    );
                  },
                  childCount: state.verses.length,
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: _buildFilteredEmptyMessage(),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  /// Build message when filter returns no results but user has verses
  Widget _buildFilteredEmptyMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr(TranslationKeys.memoryNoVersesInLanguage),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(TranslationKeys.memoryTryDifferentFilter),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.7),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.15),
                    AppTheme.secondaryPurple.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.auto_stories_outlined,
                size: 50,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Verses Yet',
              style: AppFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start building your memory verse collection.\nAdd verses to review them with spaced repetition.',
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showAddVerseOptions(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Add Your First Verse',
                          style: AppFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
      ),
    );
  }

  void _showAddVerseOptions(BuildContext context) {
    AddVerseOptionsSheet.show(
      context,
      onAddFromDaily: () => _showAddFromDailyDialog(context),
      onAddManually: () => _showAddManuallyDialog(context),
    );
  }

  void _showAddFromDailyDialog(BuildContext context) {
    // Get the current daily verse from DailyVerseBloc
    final dailyVerseState = context.read<DailyVerseBloc>().state;

    // Check if daily verse is loaded
    if (dailyVerseState is DailyVerseLoaded) {
      final verse = dailyVerseState.verse;
      final currentLanguage = dailyVerseState.currentLanguage;

      // Add the daily verse to memory deck
      context.read<MemoryVerseBloc>().add(
            AddVerseFromDaily(
              verse.id,
              language: currentLanguage.code,
            ),
          );
    } else if (dailyVerseState is DailyVerseOffline) {
      final verse = dailyVerseState.verse;
      final currentLanguage = dailyVerseState.currentLanguage;

      // Add the daily verse to memory deck even in offline mode
      context.read<MemoryVerseBloc>().add(
            AddVerseFromDaily(
              verse.id,
              language: currentLanguage.code,
            ),
          );
    } else {
      // Daily verse not loaded yet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(TranslationKeys.memoryDailyVerseNotLoaded)),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showAddManuallyDialog(BuildContext context) {
    final memoryVerseBloc = context.read<MemoryVerseBloc>();

    // Get default language: use filter if selected, otherwise use user's preferred language
    VerseLanguage defaultLanguage;
    if (_selectedLanguageFilter != null) {
      defaultLanguage = _selectedLanguageFilter!;
    } else {
      // Get user's preferred language from TranslationService
      final userLanguageCode = context.translationService.currentLanguage.code;
      defaultLanguage = _getVerseLanguageFromCode(userLanguageCode);
    }

    AddManualVerseDialog.show(
      context,
      defaultLanguage: defaultLanguage,
      onSubmit: ({
        required String verseReference,
        required String verseText,
        required String language,
      }) {
        memoryVerseBloc.add(
          AddVerseManually(
            verseReference: verseReference,
            verseText: verseText,
            language: language,
          ),
        );
      },
    );
  }

  /// Convert language code to VerseLanguage enum
  VerseLanguage _getVerseLanguageFromCode(String code) {
    switch (code) {
      case 'hi':
        return VerseLanguage.hindi;
      case 'ml':
        return VerseLanguage.malayalam;
      case 'en':
      default:
        return VerseLanguage.english;
    }
  }

  Widget _buildLanguageFilter(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(TranslationKeys.memoryFilterByLanguage),
          style: AppFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildLanguageChip(
                context,
                label: context.tr(TranslationKeys.memoryAll),
                isSelected: _selectedLanguageFilter == null,
                onTap: () {
                  setState(() => _selectedLanguageFilter = null);
                  _loadVerses();
                },
              ),
              const SizedBox(width: 8),
              ...VerseLanguage.values.map((language) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildLanguageChip(
                    context,
                    label: language.displayName,
                    isSelected: _selectedLanguageFilter == language,
                    onTap: () {
                      setState(() => _selectedLanguageFilter = language);
                      _loadVerses();
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected
              ? null
              : isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : isDark
                    ? Colors.white.withOpacity(0.1)
                    : AppTheme.primaryColor.withOpacity(0.2),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppFonts.inter(
            fontSize: 14,
            color: isSelected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    final memoryVerseBloc = context.read<MemoryVerseBloc>();
    OptionsMenuSheet.show(
      context,
      onSync: () => memoryVerseBloc
          .add(SyncWithRemote(language: _selectedLanguageFilter?.code)),
      onViewStatistics: () {
        if (_lastLoadedState != null) {
          StatisticsDialog.show(context, _lastLoadedState!.statistics);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Statistics not available. Please wait for verses to load.'),
            ),
          );
        }
      },
    );
  }

  void _navigateToReviewPage(BuildContext context, String verseId) {
    GoRouter.of(context).goToVerseReview(verseId: verseId);
  }

  void _startReviewAll(BuildContext context, List<MemoryVerseEntity> verses) {
    if (verses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(TranslationKeys.memoryNoVersesToReview)),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Get all verse IDs for sequential review
    final verseIds = verses.map((v) => v.id).toList();

    // Navigate to review page with batch mode
    GoRouter.of(context).goToVerseReview(
      verseId: verseIds.first,
      verseIds: verseIds,
    );
  }

  void _showDeleteConfirmation(BuildContext context, MemoryVerseEntity verse) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr(TranslationKeys.memoryDeleteTitle)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              verse.verseReference,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 12),
            Text(context.tr(TranslationKeys.memoryDeleteConfirmation)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr(TranslationKeys.memoryDeleteCancel)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<MemoryVerseBloc>().add(DeleteVerse(verse.id));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr(TranslationKeys.memoryDeleteConfirm)),
          ),
        ],
      ),
    );
  }

  String _getVersesToReviewMessage(BuildContext context, int count) {
    final key = count == 1
        ? TranslationKeys.memoryVersesToReviewSingular
        : TranslationKeys.memoryVersesToReviewPlural;
    return context.tr(key, {'count': count.toString()});
  }
}
