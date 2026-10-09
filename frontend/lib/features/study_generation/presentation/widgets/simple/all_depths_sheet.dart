import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/pages/generate_study_screen.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/simple/language_pill.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_mode_labels.dart';

/// "All 5" on the Generate tab: every depth as a compact row, the study
/// language and "Generate study", in a sheet over the tab.
///
/// The values that the language changes (costs, the language itself) are
/// read through callbacks, so the sheet shows the screen's fresh state after
/// [onLanguageChanged] completes. Pops with the chosen [StudyMode].
class AllDepthsSheet extends StatefulWidget {
  final List<StudyMode> modes;
  final StudyMode selected;
  final StudyMode? recommended;
  final Set<StudyMode> locked;

  /// The study can start straight away (the input is ready): the button
  /// reads "Generate study" and shows its cost, otherwise "Done".
  final bool inputReady;

  /// False on a plan that spends no credits: no cost line.
  final bool showCost;

  final int? Function(StudyMode mode) costOf;
  final StudyLanguage Function() language;
  final bool Function() languageIsDefault;
  final Future<void> Function(StudyLanguage? language) onLanguageChanged;
  final ValueChanged<StudyMode> onLockedTap;

  const AllDepthsSheet({
    super.key,
    required this.modes,
    required this.selected,
    required this.costOf,
    required this.language,
    required this.languageIsDefault,
    required this.onLanguageChanged,
    required this.onLockedTap,
    this.recommended,
    this.locked = const {},
    this.inputReady = false,
    this.showCost = true,
  });

  /// Shows the sheet; resolves to the chosen depth, or null when closed.
  static Future<StudyMode?> show(BuildContext context, AllDepthsSheet sheet) =>
      showModalBottomSheet<StudyMode>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => sheet,
      );

  @override
  State<AllDepthsSheet> createState() => _AllDepthsSheetState();
}

class _AllDepthsSheetState extends State<AllDepthsSheet> {
  late StudyMode _selected = widget.selected;

  Future<void> _changeLanguage(StudyLanguage? language) async {
    await widget.onLanguageChanged(language);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final cost = widget.costOf(_selected);
    final showCostLine = widget.inputReady && widget.showCost && cost != null;
    // Dark: the raised surface, as the design. Light: the page colour.
    final fill = palette.isDark ? palette.raised : palette.page;

    return Material(
      color: fill,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr(TranslationKeys.generateStudyChooseDepth),
                      style: AppFonts.poppins(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('all_depths_close'),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    constraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.close_rounded,
                        size: 18, color: palette.muted),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              for (final mode in widget.modes) ...[
                _DepthRow(
                  mode: mode,
                  selected: mode == _selected,
                  recommended: mode == widget.recommended,
                  locked: widget.locked.contains(mode),
                  cost: widget.costOf(mode),
                  onTap: () => widget.locked.contains(mode)
                      ? widget.onLockedTap(mode)
                      : setState(() => _selected = mode),
                ),
                const SizedBox(height: 8),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    Icon(Icons.translate_rounded,
                        size: 16, color: palette.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr(TranslationKeys.generateStudyLanguage),
                        style: AppFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                        ),
                      ),
                    ),
                    LanguagePill(
                      key: const Key('all_depths_language'),
                      selected: widget.language(),
                      isDefault: widget.languageIsDefault(),
                      onSelected: _changeLanguage,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('all_depths_generate'),
                onPressed: () => Navigator.of(context).pop(_selected),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.ctaFill,
                  foregroundColor: palette.ctaInk,
                  minimumSize: const Size.fromHeight(40),
                  visualDensity: VisualDensity.standard,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    context.tr(widget.inputReady
                        ? TranslationKeys.generateSimpleGenerate
                        : TranslationKeys.popupDone),
                    maxLines: 1,
                    style: AppFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.ctaInk,
                    ),
                  ),
                ),
              ),
              if (showCostLine) ...[
                const SizedBox(height: 6),
                Text(
                  context.tr(TranslationKeys.generateSimpleUsingCredits,
                      {'n': '$cost'}),
                  textAlign: TextAlign.center,
                  style: AppFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: palette.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One depth: icon tile, name with "8 min · 20" on the right, description.
class _DepthRow extends StatelessWidget {
  final StudyMode mode;
  final bool selected;
  final bool recommended;
  final bool locked;
  final int? cost;
  final VoidCallback onTap;

  const _DepthRow({
    required this.mode,
    required this.selected,
    required this.recommended,
    required this.locked,
    required this.cost,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final radius = BorderRadius.circular(16);
    final meta = [
      mode.localizedDuration(context),
      if (!locked && cost != null) '$cost',
    ].join(' · ');

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected
                ? palette.selectedFill
                : palette.isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : palette.outline,
          ),
        ),
        child: InkWell(
          key: ValueKey('all_depths_${mode.name}'),
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected
                        ? palette.selectedFill
                        : palette.gold
                            .withValues(alpha: palette.isDark ? 0.15 : 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    locked ? Icons.lock_outline_rounded : mode.outlineIcon,
                    size: 18,
                    color: selected ? palette.onSelected : palette.gold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              mode.localizedName(context),
                              style: AppFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: palette.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              meta,
                              style: AppFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: palette.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (recommended) ...[
                        const SizedBox(height: 2),
                        Text(
                          context
                              .tr(TranslationKeys.modeSelectionRecommendedBadge)
                              .toUpperCase(),
                          style: AppFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: palette.gold,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        locked
                            ? '${mode.localizedDescription(context)} · ${context.tr(TranslationKeys.learningPathsLocked)}'
                            : mode.localizedDescription(context),
                        style: AppFonts.inter(
                          fontSize: 12.5,
                          height: 1.4,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
