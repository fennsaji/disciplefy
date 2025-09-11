import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/purchase_history.dart';
import '../bloc/token_bloc.dart';
import '../bloc/token_event.dart';
import '../bloc/token_state.dart';
import '../widgets/purchase_history_card.dart';
import '../widgets/purchase_statistics_card.dart';

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Load initial data
    context.read<TokenBloc>().add(const GetPurchaseHistory(limit: _pageSize));
    context.read<TokenBloc>().add(const GetPurchaseStatistics());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
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
    context.read<TokenBloc>().add(const RefreshPurchaseHistory());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Purchase History'),
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
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _onRefresh();
          // Wait a bit for the refresh to complete
          await Future.delayed(const Duration(seconds: 1));
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
                      current is PurchaseHistoryError,
                  builder: (context, state) {
                    if (state is PurchaseStatisticsLoaded) {
                      return PurchaseStatisticsCard(
                        statistics: state.statistics,
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
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Failed to load statistics',
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
            ),

            // Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Transaction History',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
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
                  current is PurchaseHistoryLoaded && _isLoadingMore,
              listener: (context, state) {
                if (state is PurchaseHistoryLoaded) {
                  setState(() {
                    _isLoadingMore = false;
                  });
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
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Purchase History',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your token purchases will appear here',
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
                              'Failed to Load History',
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
                              child: const Text('Retry'),
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
    );
  }
}
