import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/auth_protected_screen.dart';
import '../../../daily_verse/domain/entities/daily_verse_entity.dart';
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

  void _loadVerses() {
    context.read<MemoryVerseBloc>().add(LoadDueVerses(
          language: _selectedLanguageFilter?.code,
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
                  onPressed: () {
                    context.read<MemoryVerseBloc>().add(const LoadDueVerses());
                  },
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
            context.read<MemoryVerseBloc>().add(const LoadDueVerses());
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
    if (state.verses.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<MemoryVerseBloc>().add(const RefreshVerses());
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
                    ),
                  );
                },
                childCount: state.verses.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
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
    // TODO: Get today's daily verse ID and add it
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add from Daily Verse - Coming soon!')),
    );
  }

  void _showAddManuallyDialog(BuildContext context) {
    final memoryVerseBloc = context.read<MemoryVerseBloc>();
    AddManualVerseDialog.show(
      context,
      defaultLanguage: _selectedLanguageFilter ?? VerseLanguage.english,
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
      onSync: () => memoryVerseBloc.add(const SyncWithRemote()),
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

  String _getVersesToReviewMessage(BuildContext context, int count) {
    final key = count == 1
        ? TranslationKeys.memoryVersesToReviewSingular
        : TranslationKeys.memoryVersesToReviewPlural;
    return context.tr(key, {'count': count.toString()});
  }
}
