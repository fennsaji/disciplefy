import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../domain/entities/purchase_history.dart';
import '../bloc/token_bloc.dart';
import '../bloc/token_event.dart';
import '../bloc/token_state.dart';
import '../widgets/purchase_history_card.dart';
import '../widgets/purchase_statistics_card.dart';
import '../../../../core/utils/logger.dart';

class PurchaseHistoryPage extends StatefulWidget {
  const PurchaseHistoryPage({super.key});

  @override
  State<PurchaseHistoryPage> createState() => _PurchaseHistoryPageState();
}

class _PurchaseHistoryPageState extends State<PurchaseHistoryPage> {
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 20;
  int _currentOffset = 0;
  bool _isLoadingMore = false;
  bool _hasTriggeredStatistics = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Load initial data
    context.read<TokenBloc>().add(const GetPurchaseHistory(limit: _pageSize));

    // Load statistics after purchase history completes
    _waitForPurchaseHistoryAndLoadStats();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
    context.read<TokenBloc>().add(GetPurchaseHistory(
          limit: _pageSize,
          offset: _currentOffset,
        ));
  }

  void _onRefresh() {
    setState(() {
      _currentOffset = 0;
      _isLoadingMore = false;
    });
    // Reload purchase history
    context.read<TokenBloc>().add(const RefreshPurchaseHistory());

    // Statistics will be loaded automatically when purchase history completes
    _waitForPurchaseHistoryAndLoadStats();
  }

  /// Wait for initial purchase history to load, then load statistics
  Future<void> _waitForPurchaseHistoryAndLoadStats() async {
    // Reset the flag for fresh operations
    if (_currentOffset == 0) {
      _hasTriggeredStatistics = false;
    }

    // Listen to BLoC state changes and trigger statistics when purchase history loads
    final subscription = context.read<TokenBloc>().stream.listen((state) {
      if (state is PurchaseHistoryLoaded &&
          mounted &&
          !_hasTriggeredStatistics &&
          state.statistics == null) {
        // Purchase history has loaded successfully and we haven't triggered stats yet
        _hasTriggeredStatistics = true;
        Logger.debug(
            '📊 [PURCHASE_HISTORY_PAGE] Purchase history loaded, triggering statistics (one-time)');
        context.read<TokenBloc>().add(const GetPurchaseStatistics());
      }
    });

    // Clean up subscription after a reasonable timeout
    Future.delayed(const Duration(seconds: 10), () {
      subscription.cancel();
    });
  }

  /// Wait for BLoC refresh operations to complete
  Future<void> _waitForRefreshCompletion() async {
    // Wait for both purchase history and statistics to load or fail
    await Future.any([
      // Wait for purchase history completion
      context
          .read<TokenBloc>()
          .stream
          .where((state) =>
              state is PurchaseHistoryLoaded || state is PurchaseHistoryError)
          .first
          .timeout(const Duration(seconds: 10)),
      // Wait for statistics completion
      context
          .read<TokenBloc>()
          .stream
          .where((state) =>
              state is PurchaseStatisticsLoaded ||
              state
                  is PurchaseHistoryError) // Note: Statistics errors use PurchaseHistoryError
          .first
          .timeout(const Duration(seconds: 10)),
    ]).catchError((_) {
      // Timeout or error - refresh indicator will complete anyway
      return TokenError(
          failure: NetworkFailure(message: 'Timeout during refresh'));
    });
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
          title: Text(context.tr('tokens.history.title')),
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
              // Statistics Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: BlocBuilder<TokenBloc, TokenState>(
                    buildWhen: (previous, current) =>
                        current is PurchaseStatisticsLoading ||
                        current is PurchaseStatisticsLoaded ||
                        current is PurchaseHistoryLoaded ||
                        current is PurchaseHistoryError,
                    builder: (context, state) {
                      if (state is PurchaseStatisticsLoaded) {
                        return PurchaseStatisticsCard(
                          statistics: state.statistics,
                        );
                      } else if (state is PurchaseHistoryLoaded &&
                          state.statistics != null) {
                        return PurchaseStatisticsCard(
                          statistics: state.statistics!,
                        );
                      } else if (state is PurchaseStatisticsLoading) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        );
                      } else if (state is PurchaseHistoryError) {
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
                                  'Something went wrong. Please try again.',
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
              ),

              // Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    context.tr('tokens.history.transaction_details'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onBackground,
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 16),
              ),

              // Purchase History List
              BlocConsumer<TokenBloc, TokenState>(
                listenWhen: (previous, current) =>
                    (current is PurchaseHistoryLoaded ||
                        current is PurchaseHistoryError) &&
                    _isLoadingMore,
                listener: (context, state) {
                  // Reset loading flag on both success and error
                  if (state is PurchaseHistoryLoaded ||
                      state is PurchaseHistoryError) {
                    setState(() {
                      _isLoadingMore = false;
                    });
                  }

                  // If this was a refresh (offset was reset), reload from beginning
                  if (state is PurchaseHistoryLoaded && _currentOffset == 0) {
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
                    current is PurchaseHistoryLoading ||
                    current is PurchaseHistoryLoaded ||
                    current is PurchaseHistoryError,
                builder: (context, state) {
                  if (state is PurchaseHistoryLoaded) {
                    if (state.isEmpty) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                context.tr('tokens.history.empty'),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.tr('tokens.history.empty_message'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index < state.purchases.length) {
                            final purchase = state.purchases[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 4.0,
                              ),
                              child: PurchaseHistoryCard(
                                purchase: purchase,
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
                        childCount:
                            state.purchases.length + (_isLoadingMore ? 1 : 0),
                      ),
                    );
                  } else if (state is PurchaseHistoryLoading) {
                    return const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  } else if (state is PurchaseHistoryError) {
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
                                context.tr('tokens.history.failed'),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Something went wrong. Please try again.',
                                style: theme.textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _onRefresh,
                                child: Text(context.tr('tokens.history.retry')),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return const SliverToBoxAdapter(
                    child: SizedBox.shrink(),
                  );
                },
              ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 16),
              ),
            ],
          ),
        ),
      ), // PopScope child: Scaffold
    ); // PopScope
  }
}
