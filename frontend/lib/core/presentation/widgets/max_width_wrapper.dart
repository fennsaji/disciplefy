import 'package:flutter/material.dart';

/// Constrains content to [maxWidth] and centers it horizontally while
/// preserving tight height constraints (so [Expanded] still works inside).
///
/// Used on desktop/tablet to keep the UI readable. Also fills the
/// background behind the constrained content with the scaffold
/// background colour so the side gutters blend naturally.
class MaxWidthWrapper extends StatelessWidget {
  /// Maximum content width. Matches the value previously set in
  /// `MaterialApp.builder`.
  static const double maxWidth = 900.0;

  final Widget child;

  const MaxWidthWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
