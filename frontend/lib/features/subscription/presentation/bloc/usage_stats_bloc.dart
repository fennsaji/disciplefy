import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/repositories/usage_stats_repository.dart';
import 'usage_stats_event.dart';
import 'usage_stats_state.dart';

/// BLoC for managing usage statistics state
///
/// Fetches and manages user usage data including:
/// - Monthly token consumption
/// - Study streak days
/// - Current subscription plan
/// - Threshold states for soft paywalls
class UsageStatsBloc extends Bloc<UsageStatsEvent, UsageStatsState> {
  final UsageStatsRepository repository;

  UsageStatsBloc({
    required this.repository,
  }) : super(const UsageStatsInitial()) {
    on<FetchUsageStats>(_onFetchUsageStats);
    on<RefreshUsageStats>(_onRefreshUsageStats);
  }

  /// Handle fetching usage statistics
  Future<void> _onFetchUsageStats(
    FetchUsageStats event,
    Emitter<UsageStatsState> emit,
  ) async {
    emit(const UsageStatsLoading());

    Logger.info(
      'Fetching usage statistics',
      tag: 'USAGE_STATS_BLOC',
    );

    final result = await repository.getUserUsageStats();

    result.fold(
      (failure) {
        Logger.error(
          'Failed to fetch usage statistics',
          tag: 'USAGE_STATS_BLOC',
          error: failure.message,
        );
        emit(UsageStatsError(message: failure.message));
      },
      (usageStats) {
        Logger.info(
          'Usage statistics loaded successfully',
          tag: 'USAGE_STATS_BLOC',
          context: {
            'plan': usageStats.currentPlan,
            'percentage': usageStats.percentage,
            'streak': usageStats.streakDays,
            'threshold': usageStats.thresholdState.name,
          },
        );
        emit(UsageStatsLoaded(usageStats: usageStats));
      },
    );
  }

  /// Handle refreshing usage statistics
  Future<void> _onRefreshUsageStats(
    RefreshUsageStats event,
    Emitter<UsageStatsState> emit,
  ) async {
    // Don't show loading state for refresh (keep current data visible)
    Logger.info(
      'Refreshing usage statistics',
      tag: 'USAGE_STATS_BLOC',
    );

    final result = await repository.getUserUsageStats();

    result.fold(
      (failure) {
        Logger.error(
          'Failed to refresh usage statistics',
          tag: 'USAGE_STATS_BLOC',
          error: failure.message,
        );
        // On refresh failure, emit error but keep existing state if available
        emit(UsageStatsError(message: failure.message));
      },
      (usageStats) {
        Logger.info(
          'Usage statistics refreshed successfully',
          tag: 'USAGE_STATS_BLOC',
          context: {
            'plan': usageStats.currentPlan,
            'percentage': usageStats.percentage,
          },
        );
        emit(UsageStatsLoaded(usageStats: usageStats));
      },
    );
  }
}
