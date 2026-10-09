import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// Quiet "Save progress to your account" row under a guest's lesson card.
/// Shown for guests only; the caller opens the account sheet in [onTap].
class SaveProgressRow extends StatelessWidget {
  final VoidCallback onTap;

  const SaveProgressRow({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Material(
      // An outlined row on the page, quieter than the lesson card above.
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.cloud_upload_outlined,
                    size: 16, color: palette.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr(TranslationKeys.homeTodaySaveProgress),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.gold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 16, color: palette.dim),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
