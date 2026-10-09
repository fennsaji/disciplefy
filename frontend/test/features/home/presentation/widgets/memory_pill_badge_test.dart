import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/memory_pill_badge.dart';

void main() {
  test('badge rule', () {
    expect(memoryBadgeCount(savedCount: 0, dueCount: 0), isNull);
    expect(memoryBadgeCount(savedCount: 0, dueCount: 3), isNull);
    expect(memoryBadgeCount(savedCount: 5, dueCount: 0), isNull);
    expect(memoryBadgeCount(savedCount: 5, dueCount: 2), 2);
  });

  Future<void> pump(WidgetTester tester, int count, {bool dark = false}) =>
      tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: Scaffold(body: Center(child: MemoryPillBadge(count: count))),
      ));

  for (final dark in [false, true]) {
    testWidgets('gold pill, dark text, at least 12pt (dark: $dark)',
        (tester) async {
      await pump(tester, 3, dark: dark);
      final text = tester.widget<Text>(find.text('3'));
      expect(text.style!.fontSize, greaterThanOrEqualTo(12));
      expect(text.style!.color!.computeLuminance(), lessThan(0.1));
      final box = tester.widget<Container>(find.byKey(MemoryPillBadge.pillKey));
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.brandGold);
      expect(tester.getSize(find.byKey(MemoryPillBadge.pillKey)).height, 16);
    });
  }

  testWidgets('caps the count at 99+', (tester) async {
    await pump(tester, 120);
    expect(find.text('99+'), findsOneWidget);
  });
}
