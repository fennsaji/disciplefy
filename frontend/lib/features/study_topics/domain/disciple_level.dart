import '../../../core/i18n/translation_keys.dart';

/// The discipleship progression a learning path's `discipleLevel` names.
///
/// The levels are a sequence — someone works through seeker, then follower,
/// then disciple, then leader — so anywhere paths are listed for a person to
/// choose from, this is the order that reads as a path rather than a pile.
/// `believer` is an older synonym for `follower` that still appears on some
/// rows, and ranks with it.
const discipleLevelOrder = <String>['seeker', 'follower', 'disciple', 'leader'];

/// Position of [level] in the progression, for sorting.
///
/// An unrecognised level sorts last rather than first: a new level nobody has
/// taught this function about should not claim to be the beginner's starting
/// point.
int discipleLevelRank(String? level) {
  final normalised = (level ?? '').toLowerCase().trim();
  if (normalised == 'believer') {
    return discipleLevelOrder.indexOf('follower');
  }
  final index = discipleLevelOrder.indexOf(normalised);
  return index == -1 ? discipleLevelOrder.length : index;
}

/// Translation key for [level]'s display name, or null when it is unrecognised
/// and should be shown as-is.
String? discipleLevelLabelKey(String? level) {
  switch ((level ?? '').toLowerCase().trim()) {
    case 'seeker':
      return TranslationKeys.discipleLevelSeeker;
    case 'believer':
      return TranslationKeys.discipleLevelBeliever;
    case 'follower':
      return TranslationKeys.discipleLevelFollower;
    case 'disciple':
      return TranslationKeys.discipleLevelDisciple;
    case 'leader':
      return TranslationKeys.discipleLevelLeader;
    default:
      return null;
  }
}
