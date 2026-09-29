import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_event.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/purchase_history_card.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/purchase_statistics_card.dart';

/// Credit-pack purchases in the K2 quiet-ledger design: a purchase summary,
/// then each purchase as a ledger entry, paginated on scroll.
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
        appBar: LedgerTopBar(
          title: context.tr(TranslationKeys.ledgerPurchasesTitle),
          subtitle: context.tr(TranslationKeys.ledgerPurchasesSubtitle),
          onBack: () => Navigator.of(context).pop(),
          actions: [
            LedgerBarAction(
              icon: Icons.sync_rounded,
              tooltip: context.tr('tokens.balance.refresh'),
              onPressed: _onRefresh,
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
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Statistics Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
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
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: LedgerLoading(),
                        );
                      } else if (state is PurchaseHistoryError) {
                        return Text(
                          context.tr('tokens.stats.failed_to_load'),
                          style: AppFonts.inter(
                              fontSize: 13.5, color: palette.muted),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
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
                        hasScrollBody: false,
                        child: LedgerMessage(
                          icon: Icons.receipt_long_outlined,
                          title: context.tr('tokens.history.empty'),
                          body: context.tr('tokens.history.empty_message'),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index < state.purchases.length) {
                              final purchase = state.purchases[index];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  PurchaseHistoryCard(purchase: purchase),
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
                              state.purchases.length + (_isLoadingMore ? 1 : 0),
                        ),
                      ),
                    );
                  } else if (state is PurchaseHistoryLoading) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: LedgerLoading(),
                    );
                  } else if (state is PurchaseHistoryError) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: LedgerMessage(
                        icon: Icons.error_outline_rounded,
                        isError: true,
                        title: context.tr('tokens.history.failed'),
                        body: context.tr(TranslationKeys.commonErrorTryAgain),
                        actionLabel: context.tr('tokens.history.retry'),
                        onAction: _onRefresh,
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
                child: SizedBox(height: 24),
              ),
            ],
          ),
        ),
      ), // PopScope child: Scaffold
    ); // PopScope
  }
}
