import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Raw semantic accents are fill colours. Painted onto text or icons they fail
/// WCAG on one theme — warning is 2.2:1 on white, brandPrimary 2.6:1 on the
/// dark surface — so widgets use the theme-resolved accessors instead
/// (`context.appSuccess`, `appWarning`, `appError`, `appInfo`,
/// `appBrandAccent`).
///
/// Fills, borders and tints are unaffected: those are written as
/// `AppColors.error.withValues(...)` and keep the base token.
void main() {
  const guarded = ['success', 'warning', 'error', 'info', 'brandPrimary'];
  const aliases = [
    'successColor',
    'warningColor',
    'errorColor',
    'primaryColor'
  ];
  final pattern = RegExp(r'(?:color|foregroundColor):\s*(?:AppColors\.(' +
      guarded.join('|') +
      r')|AppTheme\.(' +
      aliases.join('|') +
      r'))(?![.\w])');

  test('no widget paints text or icons with a raw semantic accent', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // The palette and the ThemeData definition legitimately use the raw
      // tokens — they have no BuildContext and define the themes themselves.
      if (entity.path.endsWith('app_colors.dart') ||
          entity.path.endsWith('app_theme.dart')) {
        continue;
      }

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!pattern.hasMatch(lines[i])) continue;

        final start = i - 14 < 0 ? 0 : i - 14;
        final window = lines.sublist(start, i + 1).join('\n');
        // copyWith( catches `textTheme.titleSmall?.copyWith(color: ...)`,
        // which is how most headings set their colour.
        const markers = ['Icon(', 'TextStyle(', 'copyWith('];
        if (!markers.any(window.contains)) continue;

        offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Use the theme-resolved accessor (context.appError, '
          'context.appSuccess, …) for text and icon colours:\n'
          '${offenders.join('\n')}',
    );
  });
}
