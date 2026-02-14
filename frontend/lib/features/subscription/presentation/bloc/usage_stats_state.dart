import 'package:equatable/equatable.dart';
import '../../domain/entities/usage_stats.dart';

/// Base class for all usage stats states
abstract class UsageStatsState extends Equatable {
  const UsageStatsState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any data is loaded
class UsageStatsInitial extends UsageStatsState {
  const UsageStatsInitial();
}

/// State while loading usage statistics
class UsageStatsLoading extends UsageStatsState {
  const UsageStatsLoading();
}

/// State when usage statistics are successfully loaded
class UsageStatsLoaded extends UsageStatsState {
  final UsageStats usageStats;

  const UsageStatsLoaded({required this.usageStats});

  @override
  List<Object?> get props => [usageStats];
}

/// State when there's an error fetching usage statistics
class UsageStatsError extends UsageStatsState {
  final String message;

  const UsageStatsError({required this.message});

  @override
  List<Object?> get props => [message];
}
