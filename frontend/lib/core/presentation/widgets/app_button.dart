import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';

/// Standardized button widget for consistent design across the app.
///
/// This widget provides a consistent button appearance and behavior
/// following Material Design 3 guidelines and app design standards.
class AppButton extends StatelessWidget {
  /// The text to display on the button.
  final String text;

  /// Callback function when the button is pressed.
  final VoidCallback? onPressed;

  /// Optional icon to display alongside the text.
  final IconData? icon;

  /// The style variant of the button.
  final AppButtonStyle style;

  /// Whether the button should take the full width of its parent.
  final bool isFullWidth;

  /// Whether the button is in a loading state.
  final bool isLoading;

  /// Optional tooltip text for the button.
  final String? tooltip;

  /// Creates a new AppButton widget.
  ///
  /// [text] is required and represents the button label.
  /// [onPressed] is called when the button is tapped.
  /// [style] determines the visual appearance of the button.
  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.style = AppButtonStyle.primary,
    this.isFullWidth = false,
    this.isLoading = false,
    this.tooltip,
  });

  /// Factory constructor for primary buttons.
  const AppButton.primary({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isFullWidth = false,
    this.isLoading = false,
    this.tooltip,
  }) : style = AppButtonStyle.primary;

  /// Factory constructor for secondary buttons.
  const AppButton.secondary({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isFullWidth = false,
    this.isLoading = false,
    this.tooltip,
  }) : style = AppButtonStyle.secondary;

  /// Factory constructor for outlined buttons.
  const AppButton.outlined({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isFullWidth = false,
    this.isLoading = false,
    this.tooltip,
  }) : style = AppButtonStyle.outlined;

  /// Factory constructor for text buttons.
  const AppButton.text({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isFullWidth = false,
    this.isLoading = false,
    this.tooltip,
  }) : style = AppButtonStyle.text;

  @override
  Widget build(BuildContext context) {
    Widget button = _buildButton(context);

    if (isFullWidth) {
      button = SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }

  /// Builds the appropriate button widget based on the style.
  Widget _buildButton(BuildContext context) {
    final content = _buildButtonContent();
    final isEnabled = onPressed != null && !isLoading;

    switch (style) {
      case AppButtonStyle.primary:
        return ElevatedButton(
          onPressed: isEnabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.DEFAULT_PADDING,
              vertical: AppConstants.SMALL_PADDING,
            ),
          ),
          child: content,
        );

      case AppButtonStyle.secondary:
        return FilledButton.tonal(
          onPressed: isEnabled ? onPressed : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.DEFAULT_PADDING,
              vertical: AppConstants.SMALL_PADDING,
            ),
          ),
          child: content,
        );

      case AppButtonStyle.outlined:
        return OutlinedButton(
          onPressed: isEnabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.DEFAULT_PADDING,
              vertical: AppConstants.SMALL_PADDING,
            ),
          ),
          child: content,
        );

      case AppButtonStyle.text:
        return TextButton(
          onPressed: isEnabled ? onPressed : null,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.DEFAULT_PADDING,
              vertical: AppConstants.SMALL_PADDING,
            ),
          ),
          child: content,
        );
    }
  }

  /// Builds the content of the button (text, icon, loading indicator).
  Widget _buildButtonContent() {
    if (isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                style == AppButtonStyle.outlined || style == AppButtonStyle.text
                    ? Colors.blue
                    : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(text),
        ],
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(text),
        ],
      );
    }

    return Text(text);
  }
}

/// Enumeration of button style variants.
enum AppButtonStyle {
  /// Primary elevated button with emphasis.
  primary,

  /// Secondary filled tonal button.
  secondary,

  /// Outlined button with border.
  outlined,

  /// Text button without background.
  text,
}
