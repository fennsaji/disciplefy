import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/auth_protected_screen.dart';
import '../../../daily_verse/domain/entities/daily_verse_entity.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_bloc.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_state.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              GoRouter.of(context).goToHome();
            }
          },
        ),
        title: Text(context.tr(TranslationKeys.memoryTitle)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddVerseOptions(context),
            tooltip: 'Add verse',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
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
                content: Text(context.tr(TranslationKeys.memoryDeleteSuccess)),
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  StatisticsCard(statistics: state.statistics),
                  const SizedBox(height: 16),
                  // Review All button - only show when there are due verses
                  if (state.verses.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _startReviewAll(context, state.verses),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          '${context.tr(TranslationKeys.memoryReviewAll)} (${state.verses.length})',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _buildLanguageFilter(context),
                  const SizedBox(height: 16),
                  Text(
                    '${context.tr(TranslationKeys.memoryDueForReview)} (${state.verses.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (state.statistics.dueVerses > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      _getVersesToReviewMessage(
                          context, state.statistics.dueVerses),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
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
            Icon(
              Icons.auto_stories_outlined,
              size: 80,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Verses Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start building your memory verse collection.\nAdd verses to review them with spaced repetition.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showAddVerseOptions(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Verse'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(TranslationKeys.memoryFilterByLanguage),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
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
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
