import 'package:equatable/equatable.dart';

/// Outcome of a progress reset, as reported by the `reset-progress`
/// Edge Function.
///
/// [counts] holds only the integer row counts from the backend response.
/// Boolean flags such as `streak_reset` are intentionally dropped — this
/// model exists to tell the user how much was removed.
class ResetProgressResult extends Equatable {
  /// The feature area that was reset (`learning_paths` or `memory_verses`).
  final String scope;

  /// Row counts keyed by the backend's field names.
  final Map<String, int> counts;

  const ResetProgressResult({
    required this.scope,
    required this.counts,
  });

  /// Parses the `data` object of a `reset-progress` response.
  factory ResetProgressResult.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['counts'];
    final counts = <String, int>{};

    if (rawCounts is Map) {
      rawCounts.forEach((key, value) {
        if (key is String && value is int) {
          counts[key] = value;
        }
      });
    }

    return ResetProgressResult(
      scope: json['scope'] is String ? json['scope'] as String : '',
      counts: Map.unmodifiable(counts),
    );
  }

  /// Total number of rows removed across all counted tables.
  int get totalAffected =>
      counts.values.fold<int>(0, (sum, value) => sum + value);

  @override
  List<Object?> get props => [scope, counts];
}
