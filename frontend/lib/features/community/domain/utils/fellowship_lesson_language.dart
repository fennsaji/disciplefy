import 'package:shared_preferences/shared_preferences.dart';

/// Where a member's per-group lesson language choice is stored. Kept per
/// fellowship and apart from the app-wide study language.
String fellowshipLessonsLanguagePrefKey(String fellowshipId) =>
    'fellowship_lessons_language_$fellowshipId';

/// The language a fellowship's lessons — and the study guides opened from
/// them — are shown in: the member's choice for this group, else the group's
/// own language. The member's app-wide study language is only a last resort
/// when the group language is unknown, so lesson titles and guide content
/// always match.
Future<String> resolveFellowshipLessonLanguage({
  required SharedPreferences prefs,
  required String fellowshipId,
  String? fellowshipLanguage,
  Future<String?> Function()? fetchFellowshipLanguage,
  required Future<String> Function() userStudyLanguage,
}) async {
  final chosen =
      prefs.getString(fellowshipLessonsLanguagePrefKey(fellowshipId));
  if (chosen != null && chosen.isNotEmpty) return chosen;
  if (fellowshipLanguage != null && fellowshipLanguage.isNotEmpty) {
    return fellowshipLanguage;
  }
  if (fetchFellowshipLanguage != null) {
    try {
      final fetched = await fetchFellowshipLanguage();
      if (fetched != null && fetched.isNotEmpty) return fetched;
    } catch (_) {
      // Fall through to the member's study language.
    }
  }
  return userStudyLanguage();
}
