import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/services/saved_guide_fetcher.dart';

/// A bordered, tappable row that links to a study guide.
///
/// If [studyGuideId] is set, the full saved guide is fetched by id first so
/// the destination screen can load it directly without regenerating.
/// Otherwise navigation falls back to generating/looking up the guide by its
/// input parameters (used for Discipler references that were never saved).
class StudyGuideChip extends StatefulWidget {
  final String? studyGuideId;
  final String title;
  final String? inputType;
  final String? inputValue;
  final String? language;

  const StudyGuideChip({
    this.studyGuideId,
    required this.title,
    this.inputType,
    this.inputValue,
    this.language,
    super.key,
  });

  @override
  State<StudyGuideChip> createState() => _StudyGuideChipState();
}

class _StudyGuideChipState extends State<StudyGuideChip> {
  bool _loading = false;

  Future<void> _navigate() async {
    if (_loading) return;

    final id = widget.studyGuideId;
    final inputType = widget.inputType ?? 'topic';
    final inputValue = widget.inputValue ?? widget.title;
    final language = widget.language ?? 'en';

    if (id != null && id.isNotEmpty) {
      setState(() => _loading = true);
      final data = await fetchSavedGuide(id);
      if (!mounted) return;
      setState(() => _loading = false);

      if (data != null) {
        context.push(
          '${AppRoutes.studyGuide}?source=fellowship',
          extra: {
            // Forward the whole fetched row: the viewer reads summary,
            // context, interpretation and the rest straight off this map, so
            // a hand-built stub renders every section blank. `title` is added
            // because the row stores it as `input_value`, which the viewer
            // does not look for.
            'study_guide': {
              ...data,
              'title': widget.title,
              'type': inputType,
              'input_value': inputValue,
              'language': language,
            },
          },
        );
        return;
      }
    }

    if (!mounted) return;
    context.push(
      '${AppRoutes.studyGuideV2}'
      '?input=${Uri.encodeComponent(inputValue)}'
      '&type=${Uri.encodeComponent(inputType)}'
      '&language=${Uri.encodeComponent(language)}'
      '&source=discipler',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = context.appPrimary;
    final borderColor = accent.withAlpha(isDark ? 55 : 45);
    final bgColor = accent.withAlpha(isDark ? 18 : 10);

    return InkWell(
      onTap: _loading ? null : _navigate,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            _loading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  )
                : Icon(Icons.menu_book_rounded, size: 16, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 11,
              color: accent.withAlpha(160),
            ),
          ],
        ),
      ),
    );
  }
}
