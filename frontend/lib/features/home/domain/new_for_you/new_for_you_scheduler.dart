/// "New for you": one photo banner on Home that introduces a feature the
/// person has not used yet, at most one new banner a week.
///
/// Everything here is pure so the schedule can be tested with a fixed clock.
library;

/// The features a banner can introduce. The declaration order is the
/// schedule: paths first, fellowships last.
enum NewForYouKind { paths, memory, generate, discipler, fellowships }

/// What has been shown so far, per person.
class NewForYouState {
  /// When each kind's banner was first shown.
  final Map<NewForYouKind, DateTime> firstShownAt;

  /// Kinds that were dismissed or tapped. They never come back.
  final Set<NewForYouKind> done;

  const NewForYouState({required this.firstShownAt, required this.done});

  factory NewForYouState.empty() =>
      const NewForYouState(firstShownAt: {}, done: {});

  NewForYouState copyWith({
    Map<NewForYouKind, DateTime>? firstShownAt,
    Set<NewForYouKind>? done,
  }) =>
      NewForYouState(
        firstShownAt: firstShownAt ?? this.firstShownAt,
        done: done ?? this.done,
      );

  Map<String, dynamic> toJson() => {
        'firstShownAt': {
          for (final entry in firstShownAt.entries)
            entry.key.name: entry.value.toIso8601String(),
        },
        'done': [for (final kind in done) kind.name],
      };

  /// Reads [json] leniently: unknown kinds, bad dates and wrong types are
  /// dropped rather than failing, so a stored value from another version
  /// never breaks Home.
  factory NewForYouState.fromJson(Map<String, dynamic> json) {
    final shown = <NewForYouKind, DateTime>{};
    final rawShown = json['firstShownAt'];
    if (rawShown is Map) {
      for (final entry in rawShown.entries) {
        final kind = _kindNamed(entry.key);
        final at = entry.value is String
            ? DateTime.tryParse(entry.value as String)
            : null;
        if (kind != null && at != null) shown[kind] = at;
      }
    }
    final done = <NewForYouKind>{};
    final rawDone = json['done'];
    if (rawDone is List) {
      for (final name in rawDone) {
        final kind = _kindNamed(name);
        if (kind != null) done.add(kind);
      }
    }
    return NewForYouState(firstShownAt: shown, done: done);
  }

  static NewForYouKind? _kindNamed(Object? name) {
    for (final kind in NewForYouKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

/// Which banners may be shown right now.
class NewForYouEligibility {
  /// No banner at all until lesson 1 is done.
  final bool firstLessonCompleted;

  /// Kinds whose feature is visible, not used yet and open to this person.
  final Set<NewForYouKind> available;

  const NewForYouEligibility({
    required this.firstLessonCompleted,
    required this.available,
  });
}

/// Kinds a guest can be shown. A guest only has Home and Topics, so only
/// learning paths are promoted; the other features need an account.
const Set<NewForYouKind> guestNewForYouKinds = {NewForYouKind.paths};

/// Builds the eligibility from plain signals.
///
/// A kind is available when its feature is not in [hiddenFeatures], has not
/// been used ([usedFeatures]) and, for a guest, is one of
/// [guestNewForYouKinds].
NewForYouEligibility buildEligibility({
  required bool isGuest,
  required bool firstLessonCompleted,
  Set<NewForYouKind> hiddenFeatures = const {},
  Set<NewForYouKind> usedFeatures = const {},
}) {
  return NewForYouEligibility(
    firstLessonCompleted: firstLessonCompleted,
    available: {
      for (final kind in NewForYouKind.values)
        if (!hiddenFeatures.contains(kind) &&
            !usedFeatures.contains(kind) &&
            (!isGuest || guestNewForYouKinds.contains(kind)))
          kind,
    },
  );
}

/// Study-mode feature flags. Generate is hidden only when all are.
const List<String> newForYouStudyModeKeys = [
  'quick_read_mode',
  'standard_study_mode',
  'deep_dive_mode',
  'lectio_divina_mode',
  'sermon_outline_mode',
];

/// Kinds whose feature is hidden by the feature flags, given
/// [isHidden] (`SystemConfigService.shouldHideFeature` for the user's plan).
/// Fellowships have no flag and are never hidden.
Set<NewForYouKind> hiddenNewForYouKinds(
    bool Function(String featureKey) isHidden) {
  return {
    if (isHidden('learning_paths')) NewForYouKind.paths,
    if (isHidden('memory_verses')) NewForYouKind.memory,
    if (newForYouStudyModeKeys.every(isHidden)) NewForYouKind.generate,
    if (isHidden('ai_discipler')) NewForYouKind.discipler,
  };
}

const Duration _week = Duration(days: 7);

/// The banner to show at [now], or null.
///
/// 1. Nothing until the first lesson is done.
/// 2. A kind shown less than a week ago, not done and still available keeps
///    showing.
/// 3. A new kind starts only when no kind was first shown in the last week,
///    dismissed or not: at most one new banner a week.
/// 4. The new kind is the first available kind, in enum order, never shown.
///    A shown kind older than a week is retired and never returns.
NewForYouKind? pickBanner(
  NewForYouState s,
  NewForYouEligibility e,
  DateTime now,
) {
  if (!e.firstLessonCompleted) return null;
  for (final entry in s.firstShownAt.entries) {
    final active = now.difference(entry.value) < _week;
    if (active &&
        !s.done.contains(entry.key) &&
        e.available.contains(entry.key)) {
      return entry.key;
    }
  }
  final recent = s.firstShownAt.values.any((t) => now.difference(t) < _week);
  if (recent) return null;
  for (final kind in NewForYouKind.values) {
    if (e.available.contains(kind) && !s.firstShownAt.containsKey(kind)) {
      return kind;
    }
  }
  return null;
}
