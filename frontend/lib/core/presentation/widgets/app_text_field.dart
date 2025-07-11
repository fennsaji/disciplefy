import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_constants.dart';

/// Standardized text field widget for consistent design across the app.
/// 
/// This widget provides a consistent text input appearance and behavior
/// following Material Design 3 guidelines and app design standards.
class AppTextField extends StatelessWidget {
  /// Controller for the text field.
  final TextEditingController? controller;
  
  /// Label text for the text field.
  final String labelText;
  
  /// Hint text to display when the field is empty.
  final String? hintText;
  
  /// Error text to display below the field.
  final String? errorText;
  
  /// Help text to display below the field.
  final String? helperText;
  
  /// Icon to display at the beginning of the field.
  final IconData? prefixIcon;
  
  /// Icon to display at the end of the field.
  final IconData? suffixIcon;
  
  /// Callback when the suffix icon is pressed.
  final VoidCallback? onSuffixIconPressed;
  
  /// Callback when the text changes.
  final ValueChanged<String>? onChanged;
  
  /// Callback when the user submits the field.
  final ValueChanged<String>? onSubmitted;
  
  /// Callback when the field gains focus.
  final VoidCallback? onTap;
  
  /// The type of keyboard to display.
  final TextInputType keyboardType;
  
  /// The text input action for the keyboard.
  final TextInputAction textInputAction;
  
  /// Whether the text field should obscure the text being edited.
  final bool obscureText;
  
  /// Whether the text field is enabled.
  final bool enabled;
  
  /// Whether the text field is read-only.
  final bool readOnly;
  
  /// Maximum number of lines for the text field.
  final int? maxLines;
  
  /// Maximum number of characters allowed.
  final int? maxLength;
  
  /// List of input formatters to apply to the text.
  final List<TextInputFormatter>? inputFormatters;
  
  /// Focus node for the text field.
  final FocusNode? focusNode;
  
  /// Whether to autofocus the text field.
  final bool autofocus;

  /// Creates a new AppTextField widget.
  /// 
  /// [labelText] is required and represents the field label.
  const AppTextField({
    super.key,
    this.controller,
    required this.labelText,
    this.hintText,
    this.errorText,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.focusNode,
    this.autofocus = false,
  });

  /// Factory constructor for email text fields.
  const AppTextField.email({
    super.key,
    this.controller,
    this.labelText = 'Email',
    this.hintText = 'Enter your email address',
    this.errorText,
    this.helperText,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.enabled = true,
    this.readOnly = false,
    this.focusNode,
    this.autofocus = false,
  })  : prefixIcon = Icons.email_outlined,
        suffixIcon = null,
        onSuffixIconPressed = null,
        keyboardType = TextInputType.emailAddress,
        textInputAction = TextInputAction.next,
        obscureText = false,
        maxLines = 1,
        maxLength = null,
        inputFormatters = null;

  /// Factory constructor for password text fields.
  const AppTextField.password({
    super.key,
    this.controller,
    this.labelText = 'Password',
    this.hintText = 'Enter your password',
    this.errorText,
    this.helperText,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.enabled = true,
    this.readOnly = false,
    this.focusNode,
    this.autofocus = false,
    required this.obscureText,
    required this.onSuffixIconPressed,
  })  : prefixIcon = Icons.lock_outlined,
        suffixIcon = obscureText ? Icons.visibility : Icons.visibility_off,
        keyboardType = TextInputType.visiblePassword,
        textInputAction = TextInputAction.done,
        maxLines = 1,
        maxLength = null,
        inputFormatters = null;

  /// Factory constructor for multiline text fields.
  const AppTextField.multiline({
    super.key,
    this.controller,
    required this.labelText,
    this.hintText,
    this.errorText,
    this.helperText,
    this.prefixIcon,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 5,
    this.maxLength,
    this.focusNode,
    this.autofocus = false,
  })  : suffixIcon = null,
        onSuffixIconPressed = null,
        keyboardType = TextInputType.multiline,
        textInputAction = TextInputAction.newline,
        obscureText = false,
        inputFormatters = null;

  /// Factory constructor for search text fields.
  const AppTextField.search({
    super.key,
    this.controller,
    this.labelText = 'Search',
    this.hintText = 'Search...',
    this.errorText,
    this.helperText,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.enabled = true,
    this.readOnly = false,
    this.focusNode,
    this.autofocus = false,
  })  : prefixIcon = Icons.search,
        suffixIcon = null,
        onSuffixIconPressed = null,
        keyboardType = TextInputType.text,
        textInputAction = TextInputAction.search,
        obscureText = false,
        maxLines = 1,
        maxLength = null,
        inputFormatters = null;

  @override
  Widget build(BuildContext context) => TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      autofocus: autofocus,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        errorText: errorText,
        helperText: helperText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon != null
            ? IconButton(
                icon: Icon(suffixIcon),
                onPressed: onSuffixIconPressed,
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.DEFAULT_PADDING,
          vertical: AppConstants.SMALL_PADDING,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.BORDER_RADIUS),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.BORDER_RADIUS),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.BORDER_RADIUS),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.BORDER_RADIUS),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.BORDER_RADIUS),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.BORDER_RADIUS),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
        ),
      ),
    );
}