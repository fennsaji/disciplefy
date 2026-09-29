import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_event.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/usage_history_list_item.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/usage_statistics_card.dart';

/// Usage history in the K2 quiet-ledger design: a usage summary, then every
/// spend as a ledger line, paginated on scroll.
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

  /// First usage date, kept once known so the subtitle survives state changes.
  DateTime? _since;

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
        Logger.debug(
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
  Widget _buildStatsSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: LedgerLoading(),
              );
            } else if (state is UsageHistoryError) {
              return const UsageStatisticsError();
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  /// Build section header sliver
  Widget _buildSectionHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LedgerHairline(),
            LedgerSectionLabel(
              context.tr('tokens.usage.recent_activity'),
              padding: const EdgeInsets.only(top: 18, bottom: 2),
            ),
          ],
        ),
      ),
    );
  }

  /// Build usage history list sliver
  Widget _buildHistoryList() {
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
            return _buildEmptyState();
          }

          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index < state.usageHistory.length) {
                    final usage = state.usageHistory[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        UsageHistoryListItem(usage: usage),
                        const LedgerHairline(),
                      ],
                    );
                  } else if (_isLoadingMore) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: LedgerLoading(),
                    );
                  }
                  return null;
                },
                childCount:
                    state.usageHistory.length + (_isLoadingMore ? 1 : 0),
              ),
            ),
          );
        } else if (state is UsageHistoryLoading) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: LedgerLoading(),
          );
        } else if (state is UsageHistoryError) {
          return _buildErrorState(state);
        }

        return const SliverToBoxAdapter(
          child: SizedBox.shrink(),
        );
      },
    );
  }

  /// Build empty state sliver
  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: LedgerMessage(
        icon: Icons.history_rounded,
        title: context.tr('tokens.usage.empty'),
        body: context.tr('tokens.usage.empty_message'),
      ),
    );
  }

  /// Build error state sliver
  Widget _buildErrorState(UsageHistoryError state) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: LedgerMessage(
        icon: Icons.error_outline_rounded,
        isError: true,
        title: context.tr('tokens.usage.failed'),
        body: context.tr(TranslationKeys.commonErrorTryAgain),
        actionLabel: context.tr('tokens.usage.retry'),
        onAction: _onRefresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // Handle Android back button - pop to previous page
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: palette.page,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: BlocBuilder<TokenBloc, TokenState>(
            buildWhen: (previous, current) =>
                current is UsageStatisticsLoaded ||
                current is UsageHistoryLoaded,
            builder: (context, state) {
              final stats = state is UsageStatisticsLoaded
                  ? state.statistics
                  : state is UsageHistoryLoaded
                      ? state.statistics
                      : null;
              final since = stats?.firstUsageDate;
              if (since != null) _since = since;
              return LedgerTopBar(
                title: context.tr('tokens.usage.title'),
                subtitle: _since == null
                    ? null
                    : context.tr(TranslationKeys.ledgerSince,
                        {'date': DateFormat('MMM d').format(_since!)}),
                onBack: () => Navigator.of(context).pop(),
                actions: [
                  LedgerBarAction(
                    icon: Icons.sync_rounded,
                    tooltip: context.tr('tokens.balance.refresh'),
                    onPressed: _onRefresh,
                  ),
                ],
              );
            },
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            _onRefresh();
            // Wait for BLoC to complete refresh operations
            await _waitForRefreshCompletion();
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildStatsSection(),
              _buildSectionHeader(),
              _buildHistoryList(),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ), // PopScope child: Scaffold
    ); // PopScope
  }
}
