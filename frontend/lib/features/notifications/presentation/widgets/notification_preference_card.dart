// ============================================================================
// Notification Preference Card Widget
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class NotificationPreferenceCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final Widget? trailing; // Optional trailing widget (e.g., time picker button)

  const NotificationPreferenceCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.enabled,
    required this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use explicit colors for better visibility in dark mode
    final iconBackgroundColor = isDark
        ? AppTheme.primaryColor
            .withOpacity(0.3) // Vibrant purple with 30% opacity
        : AppTheme.primaryColor
            .withOpacity(0.1); // Vibrant purple with 10% opacity

    final iconColor = isDark
        ? const Color(0xFFA78BFA) // Lighter vibrant purple for dark mode
        : AppTheme.primaryColor; // Vibrant purple for light mode

    return Card(
      elevation: 1,
      color: isDark
          ? const Color(0xFF2C2C2C)
          : null, // Explicit card color in dark mode
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => onChanged(!enabled),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : null,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? const Color(0xFFB0B0B0) // Explicit light gray
                                : Colors.grey[600],
                            height: 1.3,
                          ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(height: 12),
                      trailing!,
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: enabled,
                onChanged: onChanged,
                activeColor: isDark
                    ? const Color(0xFFA78BFA) // Lighter vibrant purple thumb
                    : AppTheme.primaryColor, // Vibrant purple thumb
                activeTrackColor: isDark
                    ? AppTheme.primaryColor.withOpacity(0.5)
                    : AppTheme.primaryColor.withOpacity(0.5),
                inactiveThumbColor: isDark
                    ? const Color(0xFF9E9E9E) // Light gray thumb
                    : const Color(0xFFBDBDBD),
                inactiveTrackColor: isDark
                    ? const Color(0xFF424242) // Dark gray track
                    : const Color(0xFFE0E0E0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
