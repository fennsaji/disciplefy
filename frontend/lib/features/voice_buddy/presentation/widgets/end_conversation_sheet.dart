import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/discipler_session_widgets.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

/// Called with the optional rating (1-5), feedback text and helpfulness;
/// the sheet closes itself afterwards.
typedef EndConversationCallback = void Function(
  int? rating,
  String? feedback,
  bool? helpful,
);

/// "End conversation?" sheet: a 5-star rating, "Was this helpful?" Yes/No,
/// optional feedback, and Keep talking / End. Every field is optional.
class EndConversationSheet extends StatefulWidget {
  final EndConversationCallback onEnd;

  const EndConversationSheet({super.key, required this.onEnd});

  /// Shows the sheet over [context].
  static Future<void> show(
    BuildContext context, {
    required EndConversationCallback onEnd,
  }) {
    return showModalBottomSheet<void>(
      // Above the floating dock, not under it.
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EndConversationSheet(onEnd: onEnd),
    );
  }

  @override
  State<EndConversationSheet> createState() => _EndConversationSheetState();
}

class _EndConversationSheetState extends State<EndConversationSheet> {
  int? _rating;
  bool? _wasHelpful;
  final TextEditingController _feedbackController = TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _submit() {
    final feedback = _feedbackController.text.trim();
    widget.onEnd(_rating, feedback.isEmpty ? null : feedback, _wasHelpful);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final question = AppFonts.inter(
      fontSize: 15,
      color: palette.muted,
      height: 1.4,
    );

    return PopupSheet(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      children: [
        Semantics(
          header: true,
          child: Text(
            context.tr('voice_buddy.conversation.end_title'),
            style: AppFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: palette.text,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(context.tr('voice_buddy.conversation.end_experience'),
            style: question),
        const SizedBox(height: 6),
        Wrap(
          children: List.generate(5, (index) {
            final value = index + 1;
            final filled = value <= (_rating ?? 0);
            return IconButton(
              onPressed: () => setState(() => _rating = value),
              tooltip: context.tr(
                TranslationKeys.voiceSessionRateStars,
                {'count': value},
              ),
              isSelected: filled,
              icon: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 34,
                color: filled ? palette.gold : palette.dim,
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Text(context.tr('voice_buddy.conversation.end_helpful'),
            style: question),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.thumb_up_outlined,
                  label: context.tr('voice_buddy.conversation.yes'),
                  selected: _wasHelpful == true,
                  onTap: () => setState(
                    () => _wasHelpful = _wasHelpful == true ? null : true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.thumb_down_outlined,
                  label: context.tr('voice_buddy.conversation.no'),
                  selected: _wasHelpful == false,
                  onTap: () => setState(
                    () => _wasHelpful = _wasHelpful == false ? null : false,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _feedbackController,
          maxLines: 3,
          minLines: 2,
          style: AppFonts.inter(fontSize: 15, color: palette.text),
          decoration: InputDecoration(
            hintText: context.tr('voice_buddy.conversation.end_feedback'),
            hintStyle: AppFonts.inter(fontSize: 15, color: palette.dim),
            filled: true,
            fillColor: palette.raised,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: palette.selectedFill),
            ),
          ),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SheetButton(
                  label: context.tr(TranslationKeys.voiceSessionKeepTalking),
                  fill: palette.raised,
                  ink: palette.text,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SheetButton(
                  label: context.tr('voice_buddy.conversation.end_button'),
                  fill: endTint(palette),
                  ink: endInk(palette),
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final ink = selected ? palette.accentIcon : palette.text;
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected
            ? palette.selectedFill
                .withValues(alpha: palette.isDark ? 0.16 : 0.07)
            : palette.raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: selected
              ? BorderSide(color: palette.selectedFill, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: ink),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
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

class _SheetButton extends StatelessWidget {
  final String label;
  final Color fill;
  final Color ink;
  final VoidCallback onPressed;

  const _SheetButton({
    required this.label,
    required this.fill,
    required this.ink,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: fill,
        foregroundColor: ink,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: const StadiumBorder(),
        elevation: 0,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppFonts.inter(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: ink,
          height: 1.25,
        ),
      ),
    );
  }
}
