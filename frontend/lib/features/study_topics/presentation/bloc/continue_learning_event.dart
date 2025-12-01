import 'package:equatable/equatable.dart';

/// Events for ContinueLearningBloc
abstract class ContinueLearningEvent extends Equatable {
  const ContinueLearningEvent();

  @override
  List<Object?> get props => [];
}

/// Load in-progress topics for continue learning section.
class LoadContinueLearning extends ContinueLearningEvent {
  /// Language code for localization
  final String language;

  /// Maximum number of topics to load
  final int limit;

  /// Whether to force a refresh (bypass cache)
  final bool forceRefresh;

  const LoadContinueLearning({
    this.language = 'en',
    this.limit = 5,
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props => [language, limit, forceRefresh];
}

/// Refresh in-progress topics (force refresh).
class RefreshContinueLearning extends ContinueLearningEvent {
  /// Language code for localization
  final String language;

  const RefreshContinueLearning({this.language = 'en'});

  @override
  List<Object?> get props => [language];
}

/// Clear cached continue learning data.
class ClearContinueLearningCache extends ContinueLearningEvent {
  const ClearContinueLearningCache();
}
