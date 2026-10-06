import 'dart:convert';
import 'dart:io';

import 'package:disciplefy_bible_study/features/study_generation/domain/entities/expected_sections.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_stream_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parity table the backend's MODE_SECTIONS is also asserted against
/// (backend/supabase/functions/_shared/services/mode-sections.test.ts).
Map<String, dynamic> _backendTable() => jsonDecode(
    File('../backend/supabase/functions/_shared/services/mode-sections.json')
        .readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('every mode lists the same keys as the backend', () {
    final table = _backendTable();
    for (final mode in StudyMode.values) {
      expect(expectedSectionKeysFor(mode), table[mode.name], reason: mode.name);
    }
    expect(table.keys.where((k) => !k.startsWith('_')).toSet(),
        StudyMode.values.map((m) => m.name).toSet());
  });

  test('the total per mode is its key count and equals the backend total', () {
    final table = _backendTable();
    for (final mode in StudyMode.values) {
      expect(expectedSectionsFor(mode), expectedSectionKeysFor(mode).length);
      expect(expectedSectionsFor(mode), (table[mode.name] as List).length);
    }
    expect(expectedSectionsFor(StudyMode.quick), 7);
  });

  test('no mode expects interpretation parts as their own sections', () {
    for (final mode in StudyMode.values) {
      expect(expectedSectionKeysFor(mode),
          isNot(contains(startsWith('interpretationPart'))));
    }
  });

  test('empty streaming content defaults its total from the mode', () {
    expect(
        StreamingStudyGuideContent.empty(mode: StudyMode.quick).totalSections,
        expectedSectionsFor(StudyMode.quick));
    expect(StreamingStudyGuideContent.empty().totalSections,
        expectedSectionsFor(StudyMode.standard));
    expect(const StreamingStudyGuideContent().totalSections,
        expectedSectionsFor(StudyMode.standard));
  });
}
