import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';

// ---------------------------------------------------------------------------
// Reaction button (tap = toggle amen, long-press = emoji picker)
// ---------------------------------------------------------------------------

/// Reaction key a tap on the pill toggles for each post type. These are the
/// stored keys; how each reads on the pill comes from [reactionDisplayFor].
String defaultReactionFor(String postType) {
  switch (postType) {
    case 'prayer':
      return 'i_prayed';
    case 'question':
      return 'heart';
    case 'study_note':
    case 'shared_guide':
    case 'daily':
      return 'fire';
    case 'praise':
    default: // general
      return 'amen';
  }
}

/// Line icon and label key for the reaction pill.
typedef ReactionDisplay = ({IconData icon, String labelKey});

/// How the pill reads on a [postType] post given the viewer's
/// [userReaction] (null when they have not reacted).
///
/// The post type's own reaction wears the type's face: "I prayed" on a
/// prayer, "Praise" on a praise report, "Helpful" on a question, "Amen" on a
/// shared guide, study note or general post, "Fire" on the daily study. A
/// different reaction picked from the long-press picker shows as itself.
ReactionDisplay reactionDisplayFor(String postType, String? userReaction) {
  final typeDefault = defaultReactionFor(postType);
  if (userReaction == null || userReaction == typeDefault) {
    switch (postType) {
      case 'prayer':
        return (
          icon: Icons.volunteer_activism_outlined,
          labelKey: TranslationKeys.communityPostReactionPrayed,
        );
      case 'praise':
        return (
          icon: Icons.celebration_outlined,
          labelKey: TranslationKeys.communityPostReactionPraise,
        );
      case 'question':
        return (
          icon: Icons.lightbulb_outline_rounded,
          labelKey: TranslationKeys.communityPostReactionHelpful,
        );
      case 'daily':
        return (
          icon: Icons.local_fire_department_outlined,
          labelKey: TranslationKeys.communityPostReactionFire,
        );
      default: // shared guide, study note, general
        return (
          icon: Icons.favorite_border_rounded,
          labelKey: TranslationKeys.communityPostReactionAmen,
        );
    }
  }
  switch (userReaction) {
    case 'i_prayed':
      return (
        icon: Icons.volunteer_activism_outlined,
        labelKey: TranslationKeys.communityPostReactionPrayed,
      );
    case 'heart':
      return (
        icon: Icons.favorite_border_rounded,
        labelKey: TranslationKeys.communityPostReactionLove,
      );
    case 'fire':
      return (
        icon: Icons.local_fire_department_outlined,
        labelKey: TranslationKeys.communityPostReactionFire,
      );
    case 'hands':
      return (
        icon: Icons.celebration_outlined,
        labelKey: TranslationKeys.communityPostReactionPraise,
      );
    case 'amen':
    default:
      return (
        icon: Icons.favorite_border_rounded,
        labelKey: TranslationKeys.communityPostReactionAmen,
      );
  }
}

/// Reaction button shared by [FellowshipPostCard] and [DailyPostCard].
///
/// Tapping toggles the default reaction for the post's type; long-pressing
/// opens a Facebook-style emoji picker. The pill shows a line icon and a
/// translated label ([reactionDisplayFor]). Reads [FellowshipFeedBloc] from
/// context.
class FellowshipReactionButton extends StatefulWidget {
  final FellowshipPostEntity post;
  final Color accentColor;

  const FellowshipReactionButton({
    required this.post,
    required this.accentColor,
    super.key,
  });

  @override
  State<FellowshipReactionButton> createState() =>
      _FellowshipReactionButtonState();
}

class _FellowshipReactionButtonState extends State<FellowshipReactionButton> {
  OverlayEntry? _pickerOverlay;

  /// Reactions offered by the long-press picker, by stored key.
  static const _kReactions = [
    (type: 'amen', emoji: '🙏'),
    (type: 'i_prayed', emoji: '🕊️'),
    (type: 'heart', emoji: '❤️'),
    (type: 'fire', emoji: '🔥'),
    (type: 'hands', emoji: '👐'),
  ];

  int get _totalCount =>
      widget.post.reactionCounts.values.fold(0, (s, c) => s + c);

  void _onTap() {
    final type =
        widget.post.userReaction ?? defaultReactionFor(widget.post.postType);
    context.read<FellowshipFeedBloc>().add(
          FellowshipReactionToggleRequested(
            postId: widget.post.id,
            reactionType: type,
          ),
        );
  }

  void _showPicker(Offset globalPosition) {
    final bloc = context.read<FellowshipFeedBloc>();
    _pickerOverlay = OverlayEntry(
      builder: (_) => _ReactionPickerOverlay(
        postId: widget.post.id,
        bloc: bloc,
        reactions: _kReactions,
        tapPosition: globalPosition,
        userReaction: widget.post.userReaction,
        onDismiss: _removePicker,
      ),
    );
    Overlay.of(context).insert(_pickerOverlay!);
  }

  void _removePicker() {
    _pickerOverlay?.remove();
    _pickerOverlay = null;
  }

  @override
  void dispose() {
    _removePicker();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final total = _totalCount;
    final isActive = widget.post.userReaction != null;
    final display = reactionDisplayFor(
      widget.post.postType,
      widget.post.userReaction,
    );
    final name = context.tr(display.labelKey);
    // Same rule as the replies button: the label always shows, with the count
    // appended, so a bare number never stands in for the action.
    final label = total > 0 ? '$name $total' : name;
    final ink = isActive ? widget.accentColor : palette.text;
    return Semantics(
      button: true,
      toggled: isActive,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _onTap,
        onLongPressStart: (d) => _showPicker(d.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          // Matches the replies button's 44px minimum touch target. No
          // alignment: the pill hugs its content, and the row below centres
          // it vertically within the 44px.
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? widget.accentColor.withAlpha(palette.isDark ? 36 : 26)
                : (palette.isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : palette.raised),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isActive
                  ? widget.accentColor.withAlpha(110)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(display.icon, size: 18, color: ink),
              const SizedBox(width: 6),
              // Wraps rather than truncating when the footer caps the pill's
              // width (long Hindi/Malayalam labels on narrow screens).
              Flexible(
                child: Text(
                  label,
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ink,
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

// ---------------------------------------------------------------------------
// Reaction picker overlay (long-press, Facebook-style)
// ---------------------------------------------------------------------------

class _ReactionPickerOverlay extends StatefulWidget {
  final String postId;
  final FellowshipFeedBloc bloc;
  final List<({String type, String emoji})> reactions;
  final Offset tapPosition;
  final String? userReaction;
  final VoidCallback onDismiss;

  const _ReactionPickerOverlay({
    required this.postId,
    required this.bloc,
    required this.reactions,
    required this.tapPosition,
    required this.userReaction,
    required this.onDismiss,
  });

  @override
  State<_ReactionPickerOverlay> createState() => _ReactionPickerOverlayState();
}

class _ReactionPickerOverlayState extends State<_ReactionPickerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _select(String type) {
    widget.bloc.add(FellowshipReactionToggleRequested(
      postId: widget.postId,
      reactionType: type,
    ));
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    const pickerWidth = 5 * 48.0 + 16.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final left = (widget.tapPosition.dx - pickerWidth / 2)
        .clamp(8.0, screenWidth - pickerWidth - 8);
    final top = (widget.tapPosition.dy - 72).clamp(
      MediaQuery.of(context).padding.top + 8,
      double.infinity,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: ScaleTransition(
            scale: _scale,
            alignment: Alignment.bottomCenter,
            child: Material(
              elevation: 10,
              borderRadius: BorderRadius.circular(32),
              color: isDark ? ReaderPalette.of(context).raised : Colors.white,
              shadowColor: Colors.black38,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.reactions.map((r) {
                    final isActive = widget.userReaction == r.type;
                    return GestureDetector(
                      onTap: () => _select(r.type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        decoration: isActive
                            ? BoxDecoration(
                                color: AppColors.brandPrimary.withAlpha(30),
                                borderRadius: BorderRadius.circular(20),
                              )
                            : null,
                        child: Text(
                          r.emoji,
                          style: TextStyle(
                            fontSize: isActive ? 26 : 22,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
