// ============================================================================
// Notification Preference Card Widget
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class NotificationPreferenceCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final Widget? trailing;

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
    const primary = AppColors.brandPrimary;
    const primaryLight = AppColors.brandPrimaryLight;

    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = enabled
        ? primary.withOpacity(isDark ? 0.4 : 0.25)
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    final iconBg = enabled
        ? (isDark ? primary.withOpacity(0.25) : AppColors.lightSurfaceVariant)
        : (isDark ? AppColors.darkSurfaceHigh : const Color(0xFFF3F4F6));

    final iconColor = enabled
        ? (isDark ? primaryLight : primary)
        : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: primary.withOpacity(isDark ? 0.12 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => onChanged(!enabled),
          borderRadius: BorderRadius.circular(16),
          splashColor: primary.withOpacity(0.08),
          highlightColor: primary.withOpacity(0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 22, color: iconColor),
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                          height: 1.4,
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(height: 10),
                        trailing!,
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Switch
                Switch(
                  value: enabled,
                  onChanged: onChanged,
                  activeColor: Colors.white,
                  activeTrackColor: primary,
                  inactiveThumbColor: isDark
                      ? const Color(0xFF6B7280)
                      : const Color(0xFFD1D5DB),
                  inactiveTrackColor: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFE5E7EB),
                  trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return primary;
                    }
                    return isDark
                        ? const Color(0xFF4B5563)
                        : const Color(0xFFD1D5DB);
                  }),
                  trackOutlineWidth: const WidgetStatePropertyAll(1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
