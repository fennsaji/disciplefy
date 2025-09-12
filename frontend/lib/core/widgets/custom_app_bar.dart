import 'package:flutter/material.dart';

/// Custom AppBar widget with consistent styling across the app
///
/// Provides a standardized app bar implementation that maintains
/// visual consistency throughout the application.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// The title text to display in the app bar
  final String title;

  /// Optional action widgets to display on the right side of the app bar
  final List<Widget>? actions;

  /// Optional leading widget to display on the left side of the app bar
  final Widget? leading;

  /// Whether to center the title text (default: true)
  final bool centerTitle;

  /// Optional background color override
  final Color? backgroundColor;

  /// Optional foreground color override for text and icons
  final Color? foregroundColor;

  /// Optional elevation override for shadow depth
  final double? elevation;

  /// Creates a CustomAppBar with the specified configuration
  ///
  /// [title] is required and displayed as the app bar title.
  /// [centerTitle] defaults to true for consistent alignment.
  /// All other parameters are optional and will use theme defaults when null.
  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
