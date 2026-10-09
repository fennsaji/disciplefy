/// "New for you": one photo banner on Home that introduces a feature the
/// person has not tried yet.
///
/// Rules (owner, 2026-10-09; replaces "one new banner a week"):
/// - Nothing in the person's first week: the first banner can show on the
///   7th calendar day after their start (account or guest creation, from the
///   server), and never before lesson 1 is completed.
/// - One kind per local day, rotating through every kind still on offer.
/// - A kind the person has tried (used the feature) or dismissed is retired
///   and never returns. Opening the banner only ends today's banner.
///
/// Everything here is pure so the schedule can be tested with a fixed clock.
library;

/// The features a banner can introduce, in rotation order.
enum NewForYouKind { paths, memory, generate, discipler, fellowships }

/// What has happened so far, per person. Stored on the device and on the
/// server (`user_new_for_you`), merged with [merge].
class NewForYouState {
  /// Kinds tried or dismissed. They never come back.
  final Set<NewForYouKind> retired;

  /// The kind shown last, and when. Both or neither.
  final NewForYouKind? lastShownKind;
  final DateTime? lastShownAt;

  /// When a banner was last opened: no banner for the rest of that day.
  final DateTime? openedAt;

  const NewForYouState({
    this.retired = const {},
    this.lastShownKind,
    this.lastShownAt,
    this.openedAt,
  });

  factory NewForYouState.empty() => const NewForYouState();

  NewForYouState copyWith({
    Set<NewForYouKind>? retired,
    NewForYouKind? lastShownKind,
    DateTime? lastShownAt,
    DateTime? openedAt,
  }) =>
      NewForYouState(
        retired: retired ?? this.retired,
        lastShownKind: lastShownKind ?? this.lastShownKind,
        lastShownAt: lastShownAt ?? this.lastShownAt,
        openedAt: openedAt ?? this.openedAt,
      );

  /// Combines two copies (device and server, or two devices): retired kinds
  /// are the union, the latest shown day wins with its kind, and the latest
  /// opened time wins.
  NewForYouState merge(NewForYouState other) {
    final mine = lastShownAt;
    final theirs = other.lastShownAt;
    final useOther = theirs != null && (mine == null || theirs.isAfter(mine));
    final opened = _latest(openedAt, other.openedAt);
    return NewForYouState(
      retired: {...retired, ...other.retired},
      lastShownKind: useOther ? other.lastShownKind : lastShownKind,
      lastShownAt: useOther ? theirs : mine,
      openedAt: opened,
    );
  }

  static DateTime? _latest(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return b.isAfter(a) ? b : a;
  }

  /// The server's shape (snake_case keys, UTC ISO dates).
  Map<String, dynamic> toJson() => {
        'retired': [for (final kind in retired) kind.name],
        if (lastShownKind != null && lastShownAt != null) ...{
          'last_shown_kind': lastShownKind!.name,
          'last_shown_at': lastShownAt!.toUtc().toIso8601String(),
        },
        if (openedAt != null) 'opened_at': openedAt!.toUtc().toIso8601String(),
      };

  /// Reads [json] leniently: unknown kinds, bad dates and wrong types are
  /// dropped rather than failing, so a stored value from another version
  /// never breaks Home.
  factory NewForYouState.fromJson(Map<String, dynamic> json) {
    final retired = <NewForYouKind>{};
    final rawRetired = json['retired'];
    if (rawRetired is List) {
      for (final name in rawRetired) {
        final kind = _kindNamed(name);
        if (kind != null) retired.add(kind);
      }
    }
    final kind = _kindNamed(json['last_shown_kind']);
    final at = _date(json['last_shown_at']);
    final both = kind != null && at != null;
    return NewForYouState(
      retired: retired,
      lastShownKind: both ? kind : null,
      lastShownAt: both ? at : null,
      openedAt: _date(json['opened_at']),
    );
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

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

  /// Kinds whose feature is visible and open to this person.
  final Set<NewForYouKind> available;

  /// The person's start (account or guest creation). Unknown: no banner.
  final DateTime? startedAt;

  const NewForYouEligibility({
    required this.firstLessonCompleted,
    required this.available,
    this.startedAt,
  });

  NewForYouEligibility withStartedAt(DateTime? startedAt) =>
      NewForYouEligibility(
        firstLessonCompleted: firstLessonCompleted,
        available: available,
        startedAt: startedAt,
      );
}

/// Kinds that need an account: a guest would only reach the account sheet.
const Set<NewForYouKind> accountOnlyNewForYouKinds = {
  NewForYouKind.memory,
  NewForYouKind.generate,
  NewForYouKind.discipler,
  NewForYouKind.fellowships,
};

/// Builds the eligibility from plain signals.
///
/// A kind is available when its feature is not in [hiddenFeatures], has not
/// been used ([usedFeatures]) and, for a guest, is not in
/// [accountOnlyNewForYouKinds].
NewForYouEligibility buildEligibility({
  required bool isGuest,
  required bool firstLessonCompleted,
  DateTime? startedAt,
  Set<NewForYouKind> hiddenFeatures = const {},
  Set<NewForYouKind> usedFeatures = const {},
}) {
  return NewForYouEligibility(
    firstLessonCompleted: firstLessonCompleted,
    startedAt: startedAt,
    available: {
      for (final kind in NewForYouKind.values)
        if (!hiddenFeatures.contains(kind) &&
            !usedFeatures.contains(kind) &&
            (!isGuest || !accountOnlyNewForYouKinds.contains(kind)))
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

/// Calendar days in the first week, when no banner is shown.
const int newForYouQuietDays = 7;

DateTime _localDay(DateTime t) {
  final local = t.toLocal();
  return DateTime(local.year, local.month, local.day);
}

bool _sameLocalDay(DateTime a, DateTime b) => _localDay(a) == _localDay(b);

/// The banner to show at [now], or null.
///
/// 1. Nothing until the first lesson is done, and nothing before the 7th
///    local calendar day after [NewForYouEligibility.startedAt].
/// 2. Nothing for the rest of a day on which a banner was opened.
/// 3. Retired kinds (tried or dismissed) and unavailable kinds are never
///    picked.
/// 4. The kind shown earlier today keeps showing today.
/// 5. Otherwise the next kind after the last one shown, in enum order,
///    wrapping round; the first kind when none was shown yet.
NewForYouKind? pickBanner(
  NewForYouState s,
  NewForYouEligibility e,
  DateTime now,
) {
  if (!e.firstLessonCompleted) return null;
  final start = e.startedAt;
  if (start == null) return null;
  final firstDay = _localDay(start);
  final eligibleFrom = DateTime(
      firstDay.year, firstDay.month, firstDay.day + newForYouQuietDays);
  if (_localDay(now).isBefore(eligibleFrom)) return null;

  final opened = s.openedAt;
  if (opened != null && _sameLocalDay(opened, now)) return null;

  bool open(NewForYouKind k) =>
      e.available.contains(k) && !s.retired.contains(k);

  final last = s.lastShownKind;
  final lastAt = s.lastShownAt;
  if (last != null && lastAt != null && _sameLocalDay(lastAt, now)) {
    if (open(last)) return last;
  }
  const kinds = NewForYouKind.values;
  if (last == null) {
    for (final k in kinds) {
      if (open(k)) return k;
    }
    return null;
  }
  for (var i = 1; i <= kinds.length; i++) {
    final k = kinds[(last.index + i) % kinds.length];
    if (open(k)) return k;
  }
  return null;
}
