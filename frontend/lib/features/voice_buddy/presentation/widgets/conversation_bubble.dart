import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/shared/widgets/clickable_scripture_text.dart';

/// Fill of the user's own bubbles: gold-tinted in both themes.
Color userBubbleFill(ReaderPalette palette) => palette.isDark
    ? palette.gold.withValues(alpha: 0.28)
    : palette.gold.withValues(alpha: 0.1);

/// A chat bubble for one message of a Discipler conversation.
///
/// The user's messages sit on the right on a gold tint. Discipler's sit on
/// the left as a hairline card with its avatar beside them; scripture
/// references inside the text are tappable, and the references the reply
/// cites are listed below it as gold chips.
class ConversationBubble extends StatelessWidget {
  /// The message content to display.
  final String content;

  /// Whether this message is from the user (true) or assistant (false).
  final bool isUser;

  /// Optional list of scripture references to display as chips.
  final List<String>? scriptureReferences;

  /// The timestamp of the message.
  final DateTime? timestamp;

  /// Callback when a scripture reference chip is tapped.
  final ValueChanged<String>? onScriptureReferenceTap;

  const ConversationBubble({
    super.key,
    required this.content,
    required this.isUser,
    this.scriptureReferences,
    this.timestamp,
    this.onScriptureReferenceTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final textStyle = AppFonts.inter(
      fontSize: 15.5,
      height: 1.55,
      color: palette.text,
    );
    final references = scriptureReferences ?? const <String>[];

    final bubble = Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: isUser ? userBubbleFill(palette) : palette.card,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 6),
          bottomRight: Radius.circular(isUser ? 6 : 20),
        ),
        border: isUser ? null : Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isUser)
            Text(content, style: textStyle)
          else
            ClickableScriptureText(
              text: content,
              style: textStyle,
              selectable: false,
            ),
          if (!isUser && references.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final ref in references)
                  ScriptureReferenceChip(
                    reference: ref,
                    onTap: onScriptureReferenceTap == null
                        ? null
                        : () => onScriptureReferenceTap!(ref),
                  ),
              ],
            ),
          ],
          if (timestamp != null) ...[
            const SizedBox(height: 6),
            Text(
              _formatTime(timestamp!),
              style: AppFonts.inter(fontSize: 11, color: palette.dim),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: 14,
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 32,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const DisciplerAvatar(radius: 14),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// Gold-tinted pill naming one scripture reference; tapping opens the verse.
class ScriptureReferenceChip extends StatelessWidget {
  final String reference;
  final VoidCallback? onTap;

  const ScriptureReferenceChip({
    super.key,
    required this.reference,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Material(
      color: palette.gold.withValues(alpha: palette.isDark ? 0.14 : 0.12),
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined, size: 15, color: palette.gold),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  reference,
                  style: AppFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.gold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Discipler's "typing" bubble shown while a reply is being prepared.
class ThinkingBubble extends StatelessWidget {
  const ThinkingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const DisciplerAvatar(radius: 14),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.hairline),
            ),
            child: const _ThinkingDots(),
          ),
        ],
      ),
    );
  }
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = ReaderPalette.of(context).accentIcon;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final value = (_controller.value + index * 0.2) % 1.0;
            final opacity =
                0.3 + 0.7 * (value < 0.5 ? value * 2 : (1 - value) * 2);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: opacity),
              ),
            );
          }),
        );
      },
    );
  }
}
