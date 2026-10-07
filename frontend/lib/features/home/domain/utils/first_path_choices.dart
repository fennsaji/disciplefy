import 'package:disciplefy_bible_study/features/onboarding/domain/growth_goals.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';

/// Slugs of the paths a guest can start, in the first-run goal order.
final List<String> guestStarterSlugs =
    GrowthGoal.values.map((g) => g.pathSlug).toList(growable: false);

/// The paths "Choose your first path" suggests, at most [limit].
///
/// - A guest sees only the guest-accessible starter paths, in the goal order
///   ([guestStarterSlugs]).
/// - Anyone else sees featured paths by `display_order`.
///
/// Either way the first-run goal's path ([goalSlug]) comes first when it is
/// in the list (and, for a guest, guest-accessible).
List<LearningPath> selectFirstPaths(
  List<LearningPath> paths, {
  required bool guest,
  String? goalSlug,
  int limit = 3,
}) {
  final List<LearningPath> ordered;
  if (guest) {
    final bySlug = {
      for (final p in paths)
        if (p.guestAccessible) p.slug: p,
    };
    ordered = [
      for (final slug in guestStarterSlugs)
        if (bySlug[slug] != null) bySlug[slug]!,
    ];
  } else {
    ordered = paths.where((p) => p.isFeatured).toList()
      ..sort((a, b) =>
          (a.displayOrder ?? 1 << 30).compareTo(b.displayOrder ?? 1 << 30));
  }

  if (goalSlug != null) {
    final goal = paths.where((p) => p.slug == goalSlug).firstOrNull;
    if (goal != null && (!guest || goal.guestAccessible)) {
      ordered
        ..removeWhere((p) => p.slug == goalSlug)
        ..insert(0, goal);
    }
  }
  return ordered.take(limit).toList();
}
