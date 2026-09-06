import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/fellowship_post_entity.dart';
import '../bloc/fellowship_feed/fellowship_feed_bloc.dart';
import '../bloc/fellowship_feed/fellowship_feed_event.dart';

// ---------------------------------------------------------------------------
// Reaction button (tap = toggle amen, long-press = emoji picker)
// ---------------------------------------------------------------------------

/// Reaction button shared by [FellowshipPostCard] and [DailyPostCard].
///
/// Tapping toggles the default reaction for the post's type; long-pressing
/// opens a Facebook-style emoji picker. Reads [FellowshipFeedBloc] from
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

  static const _kReactions = [
    (type: 'amen', emoji: '🙏'),
    (type: 'i_prayed', emoji: '🕊️'),
    (type: 'heart', emoji: '❤️'),
    (type: 'fire', emoji: '🔥'),
    (type: 'hands', emoji: '👐'),
  ];

  /// Default reaction (emoji + type + label) based on post type.
  static ({String type, String emoji, String label}) _defaultForType(
      String postType) {
    switch (postType) {
      case 'praise':
        return (type: 'amen', emoji: '🙏', label: 'Amen');
      case 'prayer':
        return (type: 'i_prayed', emoji: '🕊️', label: 'I Prayed');
      case 'question':
        return (type: 'heart', emoji: '❤️', label: 'Love');
      case 'study_note':
      case 'shared_guide':
      case 'daily':
        return (type: 'fire', emoji: '🔥', label: 'Fire');
      default: // general
        return (type: 'amen', emoji: '🙏', label: 'Amen');
    }
  }

  int get _totalCount =>
      widget.post.reactionCounts.values.fold(0, (s, c) => s + c);

  String get _activeEmoji {
    final active = widget.post.userReaction;
    if (active == null) return _defaultForType(widget.post.postType).emoji;
    return _kReactions
        .firstWhere((r) => r.type == active, orElse: () => _kReactions.first)
        .emoji;
  }

  void _onTap() {
    final type =
        widget.post.userReaction ?? _defaultForType(widget.post.postType).type;
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
    final total = _totalCount;
    final isActive = widget.post.userReaction != null;
    return GestureDetector(
      onTap: _onTap,
      onLongPressStart: (d) => _showPicker(d.globalPosition),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? widget.accentColor.withAlpha(26)
              : context.appSurfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? widget.accentColor.withAlpha(102)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_activeEmoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 5),
            Text(
              total > 0
                  ? '$total'
                  : _defaultForType(widget.post.postType).label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? widget.accentColor : context.appTextSecondary,
              ),
            ),
          ],
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
              color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
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
