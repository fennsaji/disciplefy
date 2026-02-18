import 'package:equatable/equatable.dart';

/// Base class for all usage stats events
abstract class UsageStatsEvent extends Equatable {
  const UsageStatsEvent();

  @override
  List<Object?> get props => [];
}

/// Event to fetch current usage statistics from backend
class FetchUsageStats extends UsageStatsEvent {
  const FetchUsageStats();
}

/// Event to refresh usage statistics
class RefreshUsageStats extends UsageStatsEvent {
  const RefreshUsageStats();
}
