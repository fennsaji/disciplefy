import 'package:flutter/material.dart';

/// A chat bubble widget for displaying conversation messages.
///
/// Supports both user and assistant messages with different styling,
/// including scripture reference chips for assistant responses.
class ConversationBubble extends StatelessWidget {
  /// The message content to display.
  final String content;

  /// Whether this message is from the user (true) or assistant (false).
  final bool isUser;

  /// Optional list of scripture references to display as chips.
  final List<String>? scriptureReferences;

  /// The timestamp of the message.
  final DateTime? timestamp;

  /// Callback when a scripture reference is tapped.
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
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 12,
          left: isUser ? 64 : 0,
          right: isUser ? 0 : 64,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Assistant avatar (left side)
            if (!isUser) ...[
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFFAF8F5),
                backgroundImage: AssetImage('images/AIDiscipler.png'),
              ),
              const SizedBox(width: 8),
            ],

            // Message bubble
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isUser
                      ? theme.colorScheme.primary.withAlpha((0.1 * 255).round())
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  border: isUser
                      ? Border.all(
                          color: theme.colorScheme.primary,
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Message content
                    Text(
                      content,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                        letterSpacing: 0.2,
                        fontSize: 16,
                      ),
                    ),

                    // Scripture references (for assistant messages)
                    if (!isUser &&
                        scriptureReferences != null &&
                        scriptureReferences!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: scriptureReferences!.map((ref) {
                          final isDark = theme.brightness == Brightness.dark;
                          return InkWell(
                            onTap: () => onScriptureReferenceTap?.call(ref),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF4A3B8C)
                                    : theme.colorScheme.secondary
                                        .withAlpha((0.3 * 255).round()),
                                borderRadius: BorderRadius.circular(12),
                                border: isDark
                                    ? Border.all(
                                        color: const Color(0xFF9D8FD9),
                                      )
                                    : null,
                              ),
                              child: Text(
                                ref,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isDark
                                      ? const Color(0xFFB8A9F0)
                                      : theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    // Timestamp
                    if (timestamp != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(timestamp!),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withAlpha((0.5 * 255).round()),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // User avatar (right side)
            if (isUser) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primary,
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// A loading bubble to show when the AI is "thinking".
class ThinkingBubble extends StatelessWidget {
  const ThinkingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 64),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFFAF8F5),
              backgroundImage: AssetImage('images/AIDiscipler.png'),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: const _ThinkingDots(),
            ),
          ],
        ),
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
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = (_controller.value + delay) % 1.0;
            final opacity =
                0.3 + 0.7 * (value < 0.5 ? value * 2 : (1 - value) * 2);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary
                    .withAlpha((opacity * 255).round()),
              ),
            );
          }),
        );
      },
    );
  }
}
