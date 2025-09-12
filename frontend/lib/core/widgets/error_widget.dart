import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Standard error display widget with consistent styling
///
/// Provides a unified error UI component that displays error messages
/// with optional descriptions, retry functionality, and custom icons.
class AppErrorWidget extends StatelessWidget {
  /// Primary error message to display to the user
  final String message;

  /// Optional detailed description providing more context about the error
  final String? description;

  /// Optional callback function executed when the retry button is pressed
  final VoidCallback? onRetry;

  /// Optional custom icon to display (defaults to Icons.error_outline)
  final IconData? icon;

  /// Creates an AppErrorWidget with the specified error information
  ///
  /// [message] is required and displays the main error text.
  /// [description] provides additional context when present.
  /// [onRetry] enables a retry button when provided.
  /// [icon] allows custom error icon override.
  const AppErrorWidget({
    super.key,
    required this.message,
    this.description,
    this.onRetry,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                  ),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
