import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/auth_protected_screen.dart';
import '../bloc/memory_verse_bloc.dart';
import '../bloc/memory_verse_event.dart';
import '../bloc/memory_verse_state.dart';
import '../widgets/memory_verse_list_item.dart';
import '../widgets/statistics_card.dart';

/// Home page for Memory Verses feature.
///
/// Displays:
/// - Statistics cards (total verses, due today, mastered)
/// - List of verses due for review
/// - Empty state if no verses
/// - Pull-to-refresh support
/// - Navigation to review page
class MemoryVersesHomePage extends StatefulWidget {
  const MemoryVersesHomePage({super.key});

  @override
  State<MemoryVersesHomePage> createState() => _MemoryVersesHomePageState();
}

class _MemoryVersesHomePageState extends State<MemoryVersesHomePage> {
  // Cache last loaded state to show during refresh
  DueVersesLoaded? _lastLoadedState;

  @override
  void initState() {
    super.initState();
    // Load due verses on page load
    context.read<MemoryVerseBloc>().add(const LoadDueVerses());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate back to home
            if (context.canPop()) {
              context.pop();
            } else {
              GoRouter.of(context).goToHome();
            }
          },
        ),
        title: const Text('Memory Verses'),
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
            // Reload verses after adding
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
          // Cache loaded state for use during refresh
          if (state is DueVersesLoaded) {
            _lastLoadedState = state;
          }

          // Initial state - show loading
          if (state is MemoryVerseInitial) {
            return _buildLoadingState();
          }

          // Loading without refresh - show loading
          if (state is MemoryVerseLoading && !state.isRefreshing) {
            return _buildLoadingState();
          }

          // Refreshing - show cached content or loading
          if (state is MemoryVerseLoading && state.isRefreshing) {
            // If we have cached verses, show them during refresh
            if (_lastLoadedState != null) {
              return _buildLoadedState(_lastLoadedState!);
            }
            // Otherwise show loading
            return _buildLoadingState();
          }

          // Loaded state
          if (state is DueVersesLoaded) {
            return _buildLoadedState(state);
          }

          // Error or other states - show empty
          // (Note: errors are already handled in the listener above)
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
        // Wait for refresh to complete
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: CustomScrollView(
        slivers: [
          // Statistics section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Progress',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  StatisticsCard(statistics: state.statistics),
                  const SizedBox(height: 24),
                  Text(
                    'Due for Review (${state.verses.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (state.statistics.motivationalMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.statistics.motivationalMessage,
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

          // Verse list
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

          // Bottom spacing
          const SliverToBoxAdapter(
            child: SizedBox(height: 16),
          ),
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

  void _showAddVerseOptions(BuildContext parentContext) {
    showModalBottomSheet(
      context: parentContext,
      builder: (bottomSheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('Add from Daily Verse'),
              subtitle: const Text("Add today's verse to your memory deck"),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _showAddFromDailyDialog(parentContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Add Custom Verse'),
              subtitle: const Text('Enter any Bible verse manually'),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _showAddManuallyDialog(parentContext);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAddFromDailyDialog(BuildContext context) {
    // TODO: Implement - Get today's daily verse ID and add it
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add from Daily Verse - Coming soon!'),
      ),
    );
  }

  void _showAddManuallyDialog(BuildContext context) {
    final referenceController = TextEditingController();
    final textController = TextEditingController();

    // Capture BLoC before showing dialog
    final memoryVerseBloc = context.read<MemoryVerseBloc>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        // State variables for validation errors
        String? referenceError;
        String? textError;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Custom Verse'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: referenceController,
                      decoration: InputDecoration(
                        labelText: 'Verse Reference',
                        hintText: 'e.g., John 3:16',
                        border: const OutlineInputBorder(),
                        errorText: referenceError,
                      ),
                      onChanged: (_) {
                        // Clear error when user starts typing
                        if (referenceError != null) {
                          setState(() {
                            referenceError = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: textController,
                      decoration: InputDecoration(
                        labelText: 'Verse Text',
                        hintText: 'Enter the full verse...',
                        border: const OutlineInputBorder(),
                        errorText: textError,
                      ),
                      maxLines: 4,
                      onChanged: (_) {
                        // Clear error when user starts typing
                        if (textError != null) {
                          setState(() {
                            textError = null;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Trim input values
                    final trimmedReference = referenceController.text.trim();
                    final trimmedText = textController.text.trim();

                    // Validate trimmed values
                    bool hasError = false;

                    if (trimmedReference.isEmpty) {
                      setState(() {
                        referenceError = 'Verse reference is required';
                      });
                      hasError = true;
                    }

                    if (trimmedText.isEmpty) {
                      setState(() {
                        textError = 'Verse text is required';
                      });
                      hasError = true;
                    }

                    // Only dispatch and close if validation passes
                    if (!hasError) {
                      memoryVerseBloc.add(
                        AddVerseManually(
                          verseReference: trimmedReference,
                          verseText: trimmedText,
                        ),
                      );
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showOptionsMenu(BuildContext context) {
    // Capture BLoC before showing bottom sheet
    final memoryVerseBloc = context.read<MemoryVerseBloc>();

    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Sync with Server'),
              subtitle: const Text('Upload pending offline changes'),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                memoryVerseBloc.add(const SyncWithRemote());
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('View Statistics'),
              subtitle: const Text('See your progress details'),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                // TODO: Navigate to statistics page
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _navigateToReviewPage(BuildContext context, String verseId) {
    // Use GoRouter extension for navigation
    GoRouter.of(context).goToVerseReview(verseId: verseId);
  }
}
