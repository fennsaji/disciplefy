import 'package:disciplefy_bible_study/features/study_generation/data/datasources/study_local_data_source.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_status.dart';

/// What starting a study should do.
enum LaunchDecision {
  /// A matching guide is already on the device — open it, no credits needed.
  openCached,

  /// Generate a new guide (the backend charges the credits).
  openNew,

  /// The user does not have enough credits for this study mode.
  needCredits,
}

/// Shared "cache → credits → navigate" checks used by the generate screens.
class StudyLaunchService {
  StudyLaunchService(this._local);

  final StudyLocalDataSource _local;

  /// Decides how to start a study for [input].
  ///
  /// A cached guide (same input, ignoring case and spaces, same [type] and
  /// [language]) always opens without a credit check. Premium/unlimited plans
  /// and an unknown [status] go straight to generation; otherwise the user
  /// needs at least [cost] credits. A [cost] of 0 (unknown) never blocks.
  Future<LaunchDecision> decide({
    required String input,
    required String type,
    required String language,
    required StudyMode mode,
    required TokenStatus? status,
    required int cost,
  }) async {
    if (await _hasCachedStudyGuide(input, type, language)) {
      return LaunchDecision.openCached;
    }
    if (status != null && !status.isPremium && !status.unlimitedUsage) {
      if (cost > 0 && status.totalTokens < cost) {
        return LaunchDecision.needCredits;
      }
    }
    return LaunchDecision.openNew;
  }

  /// The study guide route for these launch parameters.
  String location({
    required String input,
    required String type,
    required String language,
    required StudyMode mode,
    String source = 'generate',
  }) {
    final encodedInput = Uri.encodeComponent(input);
    return '/study-guide-v2?input=$encodedInput&type=$type&language=$language&mode=${mode.name}&source=$source';
  }

  Future<bool> _hasCachedStudyGuide(
    String input,
    String inputType,
    String language,
  ) async {
    try {
      final cached = await _local.getCachedStudyGuides();
      final normalizedInput = input.trim().toLowerCase();
      return cached.any(
        (g) =>
            g.input.trim().toLowerCase() == normalizedInput &&
            g.inputType == inputType &&
            g.language == language,
      );
    } catch (_) {
      return false;
    }
  }
}
