import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../domain/entities/token_usage_history.dart';
import '../bloc/token_bloc.dart';
import '../bloc/token_event.dart';
import '../bloc/token_state.dart';
import '../widgets/usage_history_list_item.dart';
import '../widgets/usage_statistics_card.dart';

class TokenUsageHistoryPage extends StatefulWidget {
  const TokenUsageHistoryPage({super.key});

  @override
  State<TokenUsageHistoryPage> createState() => _TokenUsageHistoryPageState();
}

class _TokenUsageHistoryPageState extends State<TokenUsageHistoryPage> {
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 20;
  int _currentOffset = 0;
  bool _isLoadingMore = false;
  bool _hasTriggeredStatistics = false;
  StreamSubscription<TokenState>? _usageHistorySubscription;
  Timer? _usageHistoryTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Load initial data
    context.read<TokenBloc>().add(const GetUsageHistory(limit: _pageSize));

    // Load statistics after usage history completes
    _waitForUsageHistoryAndLoadStats();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _usageHistorySubscription?.cancel();
    _usageHistoryTimeoutTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    // Prevent premature triggering - wait until much closer to bottom (95%)
    // and ensure we have scrollable content
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.95 &&
        _scrollController.position.maxScrollExtent > 0) {
      _loadMoreHistory();
    }
  }

  void _loadMoreHistory() {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    _currentOffset += _pageSize;
    context.read<TokenBloc>().add(GetUsageHistory(
          limit: _pageSize,
          offset: _currentOffset,
        ));
  }

  void _onRefresh() {
    setState(() {
      _currentOffset = 0;
      _isLoadingMore = false;
    });
    // Reload usage history
    context.read<TokenBloc>().add(const RefreshUsageHistory());

    // Statistics will be loaded automatically when usage history completes
    _waitForUsageHistoryAndLoadStats();
  }

  /// Wait for initial usage history to load, then load statistics
  Future<void> _waitForUsageHistoryAndLoadStats() async {
    // Reset the flag for fresh operations
    if (_currentOffset == 0) {
      _hasTriggeredStatistics = false;
    }

    // Cancel any existing subscription and timer
    await _usageHistorySubscription?.cancel();
    _usageHistoryTimeoutTimer?.cancel();

    // Listen to BLoC state changes and trigger statistics when usage history loads
    final newSubscription = context.read<TokenBloc>().stream.listen((state) {
      if (state is UsageHistoryLoaded &&
          mounted &&
          !_hasTriggeredStatistics &&
          state.statistics == null) {
        // Usage history has loaded successfully and we haven't triggered stats yet
        _hasTriggeredStatistics = true;
        debugPrint(
            '📊 [USAGE_HISTORY_PAGE] Usage history loaded, triggering statistics (one-time)');
        context.read<TokenBloc>().add(const GetUsageStatistics());

        // Cancel subscription immediately after triggering statistics
        _usageHistorySubscription?.cancel();
        _usageHistorySubscription = null;
        _usageHistoryTimeoutTimer?.cancel();
        _usageHistoryTimeoutTimer = null;
      }
    });

    // Store the new subscription
    _usageHistorySubscription = newSubscription;

    // Clean up subscription after a reasonable timeout as a safety measure
    // Only cancel if this is still the active subscription
    _usageHistoryTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (_usageHistorySubscription == newSubscription) {
        _usageHistorySubscription?.cancel();
        _usageHistorySubscription = null;
      }
      _usageHistoryTimeoutTimer = null;
    });
  }

  /// Wait for BLoC refresh operations to complete
  Future<void> _waitForRefreshCompletion() async {
    // Wait for both usage history and statistics to load or fail
    await Future.wait([
      // Wait for usage history completion
      context
          .read<TokenBloc>()
          .stream
          .where((state) =>
              state is UsageHistoryLoaded || state is UsageHistoryError)
          .first
          .timeout(const Duration(seconds: 10)),
      // Wait for statistics completion
      context
          .read<TokenBloc>()
          .stream
          .where((state) =>
              state is UsageStatisticsLoaded || state is UsageHistoryError)
          .first
          .timeout(const Duration(seconds: 10)),
    ]).catchError((_) {
      // Timeout or error - refresh indicator will complete anyway
      return [
        TokenError(failure: NetworkFailure(message: 'Timeout during refresh'))
      ];
    });
  }

  /// Build statistics section sliver
  Widget _buildStatsSection(ThemeData theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BlocBuilder<TokenBloc, TokenState>(
          buildWhen: (previous, current) =>
              current is UsageStatisticsLoading ||
              current is UsageStatisticsLoaded ||
              current is UsageHistoryLoaded ||
              current is UsageHistoryError,
          builder: (context, state) {
            if (state is UsageStatisticsLoaded) {
              return UsageStatisticsCard(
                statistics: state.statistics,
              );
            } else if (state is UsageHistoryLoaded &&
                state.statistics != null) {
              return UsageStatisticsCard(
                statistics: state.statistics!,
              );
            } else if (state is UsageStatisticsLoading) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            } else if (state is UsageHistoryError) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.error,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('tokens.stats.failed_to_load'),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.errorMessage,
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  /// Build section header sliver
  Widget _buildSectionHeader(ThemeData theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Text(
          context.tr('tokens.usage.recent_activity'),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onBackground,
          ),
        ),
      ),
    );
  }

  /// Build usage history list sliver
  Widget _buildHistoryList(ThemeData theme) {
    return BlocConsumer<TokenBloc, TokenState>(
      listenWhen: (previous, current) =>
          (current is UsageHistoryLoaded || current is UsageHistoryError) &&
          _isLoadingMore,
      listener: (context, state) {
        // Reset loading flag on both success and error
        if (state is UsageHistoryLoaded || state is UsageHistoryError) {
          setState(() {
            _isLoadingMore = false;
          });
        }

        // If this was a refresh (offset was reset), reload from beginning
        if (state is UsageHistoryLoaded && _currentOffset == 0) {
          // Reset scroll position to top after refresh
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        }
      },
      buildWhen: (previous, current) =>
          current is UsageHistoryLoading ||
          current is UsageHistoryLoaded ||
          current is UsageHistoryError,
      builder: (context, state) {
        if (state is UsageHistoryLoaded) {
          if (state.isEmpty) {
            return _buildEmptyState(theme);
          }

          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index < state.usageHistory.length) {
                  final usage = state.usageHistory[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 4.0,
                    ),
                    child: UsageHistoryListItem(
                      usage: usage,
                    ),
                  );
                } else if (_isLoadingMore) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                return null;
              },
              childCount: state.usageHistory.length + (_isLoadingMore ? 1 : 0),
            ),
          );
        } else if (state is UsageHistoryLoading) {
          return const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (state is UsageHistoryError) {
          return _buildErrorState(theme, state);
        }

        return const SliverToBoxAdapter(
          child: SizedBox.shrink(),
        );
      },
    );
  }

  /// Build empty state sliver
  Widget _buildEmptyState(ThemeData theme) {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('tokens.usage.empty'),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('tokens.usage.empty_message'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build error state sliver
  Widget _buildErrorState(ThemeData theme, UsageHistoryError state) {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('tokens.usage.failed'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.errorMessage,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _onRefresh,
                child: Text(context.tr('tokens.usage.retry')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // Handle Android back button - pop to previous page
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(context.tr('tokens.usage.title')),
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _onRefresh,
              tooltip: context.tr('tokens.balance.refresh'),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            _onRefresh();
            // Wait for BLoC to complete refresh operations
            await _waitForRefreshCompletion();
          },
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildStatsSection(theme),
              _buildSectionHeader(theme),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              _buildHistoryList(theme),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),
      ), // PopScope child: Scaffold
    ); // PopScope
  }
}
