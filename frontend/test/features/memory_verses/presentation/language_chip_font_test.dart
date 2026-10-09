import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('language chips use the Indic fallback', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Row(children: [
          MemoryChoiceChip(label: 'മലയാളം', selected: false, onTap: () {}),
          MemoryChoiceChip(label: 'हिन्दी', selected: true, onTap: () {}),
        ]),
      ),
    ));
    for (final label in ['മലയാളം', 'हिन्दी']) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.fontFamilyFallback,
          containsAll(['NotoSansDevanagari', 'NotoSansMalayalam']));
    }
  });
}
