import 'package:flutter/material.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/study_mode.dart';

/// Bottom sheet for selecting study mode before generating a study guide.
///
/// Presents 4 study mode options (Quick, Standard, Deep, Lectio) with
/// visual icons, durations, and descriptions. Optionally allows users
/// to remember their choice for future sessions.
class ModeSelectionSheet extends StatefulWidget {
  /// Callback when user selects a mode.
  final void Function(StudyMode mode, bool rememberChoice) onModeSelected;

  /// The initially selected mode (defaults to standard).
  final StudyMode initialMode;

  /// Whether to show the "Remember my choice" checkbox.
  final bool showRememberOption;

  const ModeSelectionSheet({
    super.key,
    required this.onModeSelected,
    this.initialMode = StudyMode.standard,
    this.showRememberOption = true,
  });

  /// Shows the mode selection sheet as a modal bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required void Function(StudyMode mode, bool rememberChoice) onModeSelected,
    StudyMode initialMode = StudyMode.standard,
    bool showRememberOption = true,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModeSelectionSheet(
        onModeSelected: onModeSelected,
        initialMode: initialMode,
        showRememberOption: showRememberOption,
      ),
    );
  }

  @override
  State<ModeSelectionSheet> createState() => _ModeSelectionSheetState();
}

class _ModeSelectionSheetState extends State<ModeSelectionSheet> {
  late StudyMode _selectedMode;
  bool _rememberChoice = false;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: bottomPadding + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.2)
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'How would you like to study?',
                style: AppFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a study mode based on your available time',
                style: AppFonts.inter(
                  fontSize: 14,
                  color: isDark
                      ? Colors.white.withOpacity(0.6)
                      : const Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Mode options
              ...StudyMode.values.map((mode) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ModeOptionCard(
                      mode: mode,
                      isSelected: _selectedMode == mode,
                      isDefault: mode == StudyMode.standard,
                      onTap: () {
                        setState(() {
                          _selectedMode = mode;
                        });
                      },
                    ),
                  )),

              const SizedBox(height: 8),

              // Remember choice checkbox
              if (widget.showRememberOption)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _rememberChoice = !_rememberChoice;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _rememberChoice
                                ? AppTheme.primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _rememberChoice
                                  ? AppTheme.primaryColor
                                  : isDark
                                      ? Colors.white.withOpacity(0.3)
                                      : const Color(0xFFD1D5DB),
                              width: 2,
                            ),
                          ),
                          child: _rememberChoice
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Remember my choice',
                          style: AppFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.white.withOpacity(0.7)
                                : const Color(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Continue button
              Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onModeSelected(_selectedMode, _rememberChoice);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedMode.iconData,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Start ${_selectedMode.displayName}',
                            style: AppFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _selectedMode.durationText,
                              style: AppFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

/// Individual mode option card widget.
class _ModeOptionCard extends StatelessWidget {
  final StudyMode mode;
  final bool isSelected;
  final bool isDefault;
  final VoidCallback onTap;

  const _ModeOptionCard({
    required this.mode,
    required this.isSelected,
    required this.isDefault,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? isDark
                  ? AppTheme.primaryColor.withOpacity(0.15)
                  : const Color(0xFFF3F0FF)
              : isDark
                  ? Colors.white.withOpacity(0.05)
                  : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : isDark
                    ? Colors.white.withOpacity(0.1)
                    : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withOpacity(0.15)
                    : isDark
                        ? Colors.white.withOpacity(0.1)
                        : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                mode.iconData,
                size: 24,
                color: isSelected
                    ? AppTheme.primaryColor
                    : isDark
                        ? Colors.white.withOpacity(0.7)
                        : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 16),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          mode.displayName,
                          style: AppFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : isDark
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Default',
                            style: AppFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mode.description,
                    style: AppFonts.inter(
                      fontSize: 13,
                      color: isDark
                          ? Colors.white.withOpacity(0.6)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),

            // Duration badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : isDark
                        ? Colors.white.withOpacity(0.1)
                        : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                mode.durationText,
                style: AppFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : isDark
                          ? Colors.white.withOpacity(0.7)
                          : const Color(0xFF4B5563),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : isDark
                          ? Colors.white.withOpacity(0.3)
                          : const Color(0xFFD1D5DB),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
