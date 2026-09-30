import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/discipler_session_widgets.dart';
import 'package:disciplefy_bible_study/shared/widgets/welcome_chrome.dart';

/// Suggested first questions, as keys; tapping one sends its text.
const List<String> disciplerSuggestionKeys = [
  TranslationKeys.voiceSessionSuggestion1,
  TranslationKeys.voiceSessionSuggestion2,
  TranslationKeys.voiceSessionSuggestion3,
];

/// The Discipler tab before a conversation: a photo header with the monthly
/// allowance and settings, the title and description, the language chip,
/// "Start talking" / "Type", and suggested questions.
class DisciplerStartView extends StatelessWidget {
  /// Allowance chip; null hides it.
  final QuotaDisplay? quota;

  /// Name of the language Discipler will speak.
  final String languageName;

  /// Back arrow, shown only when the page is pushed (not as a tab).
  final VoidCallback? onBack;
  final VoidCallback onSettings;
  final VoidCallback onLanguageTap;
  final VoidCallback onStartTalking;
  final VoidCallback onType;
  final ValueChanged<String> onSuggestion;

  const DisciplerStartView({
    super.key,
    required this.quota,
    required this.languageName,
    required this.onSettings,
    required this.onLanguageTap,
    required this.onStartTalking,
    required this.onType,
    required this.onSuggestion,
    this.onBack,
  });

  static const double _photoHeight = 300;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final topInset = MediaQuery.paddingOf(context).top;

    return SingleChildScrollView(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _photoHeight + topInset,
            child: const WelcomePhotoBackdrop(
                asset: disciplerHeaderPhoto, blurred: true),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopRow(context, palette),
                const SizedBox(height: 72),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WelcomeEyebrow(context.tr('voice_buddy.title')),
                      const SizedBox(height: 8),
                      Semantics(
                        header: true,
                        child: WelcomeTitle(
                          context.tr(TranslationKeys.voiceSessionHeadline),
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.tr('voice_buddy.description'),
                        style: AppFonts.inter(
                          fontSize: 15,
                          height: 1.45,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _LanguageChip(languageName: languageName, onTap: onLanguageTap),
                const SizedBox(height: 16),
                _buildActions(context, palette),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SessionLabel(
                    context.tr(TranslationKeys.voiceSessionTryAsking),
                  ),
                ),
                const SizedBox(height: 12),
                for (final key in disciplerSuggestionKeys) ...[
                  _SuggestionCard(
                    text: context.tr(key),
                    onTap: () => onSuggestion(context.tr(key)),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRow(BuildContext context, ReaderPalette palette) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBack != null) ...[
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            color: palette.text,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: quota != null && quota!.isVisible
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: DisciplerQuotaChip(display: quota!, onPhoto: true),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined),
          color: palette.text,
          tooltip: context.tr('voice_buddy.settings.title'),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, ReaderPalette palette) {
    final startTalking = FilledButton(
      onPressed: onStartTalking,
      style: FilledButton.styleFrom(
        backgroundColor: palette.ctaFill,
        foregroundColor: palette.ctaInk,
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: const StadiumBorder(),
        elevation: 0,
      ),
      child: _IconLabel(
        icon: Icons.mic_none_rounded,
        label: context.tr(TranslationKeys.voiceSessionStartTalking),
        color: palette.ctaInk,
      ),
    );
    final type = FilledButton(
      onPressed: onType,
      style: FilledButton.styleFrom(
        backgroundColor: palette.raised,
        foregroundColor: palette.text,
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: const StadiumBorder(),
        elevation: 0,
      ),
      child: _IconLabel(
        icon: Icons.keyboard_outlined,
        label: context.tr(TranslationKeys.voiceSessionType),
        color: palette.text,
      ),
    );

    final typeLabel = context.tr(TranslationKeys.voiceSessionType);
    return LayoutBuilder(
      builder: (context, box) {
        // Side by side while "Type" fits in its natural width next to a
        // comfortable "Start talking"; stacked full width otherwise, so
        // neither label is squeezed into a character-by-character wrap.
        final painter = TextPainter(
          text: TextSpan(
            text: typeLabel,
            style: AppFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final typeWidth = painter.width + 20 + 8 + 32 + 2;
        painter.dispose();
        if (typeWidth <= box.maxWidth * 0.4) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: startTalking),
                const SizedBox(width: 10),
                SizedBox(width: typeWidth, child: type),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [startTalking, const SizedBox(height: 10), type],
        );
      },
    );
  }
}

/// Icon + label that wraps rather than truncating.
class _IconLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _IconLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String languageName;
  final VoidCallback onTap;

  const _LanguageChip({required this.languageName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Tooltip(
      message: context.tr(TranslationKeys.voiceSessionChangeLanguage),
      child: Material(
        color: palette.raised,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language, size: 20, color: palette.accentIcon),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    context.tr(
                      TranslationKeys.voiceSessionSpeakingLanguage,
                      {'language': languageName},
                    ),
                    style: AppFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 20, color: palette.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SuggestionCard({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Material(
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: palette.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Icon(Icons.subdirectory_arrow_right_rounded,
                    size: 20, color: palette.accentIcon),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: AppFonts.inter(
                      fontSize: 15,
                      color: palette.text,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.north_east_rounded, size: 16, color: palette.dim),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
