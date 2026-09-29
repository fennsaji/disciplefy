/// Scenery photos behind the photo headers (home verse, Generate, study guide
/// and the library's Continue card). All are 2000px wide; decode them at the
/// box's pixel width, never the full source.
const List<String> heroImages = [
  'assets/images/hero/mountains_fog.jpg',
  'assets/images/hero/mountains_dawn.jpg',
  'assets/images/hero/valley_mist.jpg',
  'assets/images/hero/winter_sunset.jpg',
  'assets/images/hero/wheat_dawn.jpg',
  'assets/images/hero/night_stars.jpg',
  'assets/images/hero/desert_dunes.jpg',
  'assets/images/hero/green_hills.jpg',
  'assets/images/hero/snow_peaks.jpg',
];

/// A photo for [date]: stable within a calendar day, rotates across days.
/// [offset] lets two screens shown on the same day use different photos.
String heroImageForDay(DateTime date, {int offset = 0}) {
  final dayIndex =
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay;
  return heroImages[(dayIndex + offset) % heroImages.length];
}

/// A photo tied to [key] (e.g. a guide's title), so the same guide always
/// shows the same scenery — in its header and on its library card.
///
/// Uses its own hash: `String.hashCode` is not stable across runs.
String heroImageForKey(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.trim().toLowerCase().codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return heroImages[hash % heroImages.length];
}
