import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/utils/detect_study_input.dart';

/// Small gold tag naming what the Generate input was read as (Scripture,
/// Topic or Question). Tapping it moves to the next type, so the user can
/// correct a wrong guess.
class InputTypeTag extends StatelessWidget {
  final DetectedInputType type;
  final VoidCallback onTap;

  const InputTypeTag({
    super.key = const Key('input_type_tag'),
    required this.type,
    required this.onTap,
  });

  /// The type a tap moves to: scripture → topic → question → scripture.
  static DetectedInputType next(DetectedInputType type) => switch (type) {
        DetectedInputType.scripture => DetectedInputType.topic,
        DetectedInputType.topic => DetectedInputType.question,
        DetectedInputType.question => DetectedInputType.scripture,
      };

  static String label(BuildContext context, DetectedInputType type) =>
      context.tr(switch (type) {
        DetectedInputType.scripture =>
          TranslationKeys.generateSimpleTypeScripture,
        DetectedInputType.topic => TranslationKeys.generateSimpleTypeTopic,
        DetectedInputType.question =>
          TranslationKeys.generateSimpleTypeQuestion,
      });

  static IconData _icon(DetectedInputType type) => switch (type) {
        DetectedInputType.scripture => Icons.menu_book_outlined,
        DetectedInputType.topic => Icons.lightbulb_outline_rounded,
        DetectedInputType.question => Icons.help_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final gold = palette.gold;
    // Deep gold is about 4:1 on its own tint; the tint label gold is 5.9:1.
    final ink = palette.goldOnTint;
    return Semantics(
      button: true,
      child: Material(
        color: gold.withValues(alpha: 0.16),
        shape:
            StadiumBorder(side: BorderSide(color: gold.withValues(alpha: 0.5))),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icon(type), size: 14, color: ink),
                  const SizedBox(width: 6),
                  Text(
                    label(context, type),
                    style: AppFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
