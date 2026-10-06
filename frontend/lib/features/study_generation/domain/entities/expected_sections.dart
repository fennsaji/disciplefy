import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';

/// The seven sections every mode's prompt schema asks for, in stream order.
/// Multi-pass interpretation parts arrive combined as `interpretation`.
const List<String> _sevenSections = [
  'summary',
  'context',
  'passage',
  'interpretation',
  'relatedVerses',
  'reflectionQuestions',
  'prayerPoints',
];

/// Section keys a study stream in [mode] sends, in order.
///
/// Must match the backend's `MODE_SECTIONS`
/// (`_shared/services/mode-sections.ts`); both sides are asserted against
/// the shared table `_shared/services/mode-sections.json`. Every mode streams
/// the same seven keys today; the per-mode switch lets one differ later.
List<String> expectedSectionKeysFor(StudyMode mode) => switch (mode) {
      StudyMode.quick => _sevenSections,
      StudyMode.standard => _sevenSections,
      StudyMode.deep => _sevenSections,
      StudyMode.lectio => _sevenSections,
      StudyMode.sermon => _sevenSections,
    };

/// Number of sections a study stream in [mode] sends.
int expectedSectionsFor(StudyMode mode) => expectedSectionKeysFor(mode).length;
