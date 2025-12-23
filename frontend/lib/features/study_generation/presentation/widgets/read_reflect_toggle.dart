import 'package:flutter/material.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../domain/entities/study_mode.dart';

/// Toggle button for switching between Read and Reflect modes.
///
/// Read Mode: Traditional scrollable study guide content
/// Reflect Mode: Interactive card-by-card progression with prompts
class ReadReflectToggle extends StatelessWidget {
  /// Current view mode
  final StudyViewMode currentMode;

  /// Callback when mode changes
  final ValueChanged<StudyViewMode> onModeChanged;

  const ReadReflectToggle({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              context,
              mode: StudyViewMode.read,
              icon: Icons.menu_book_outlined,
              label: 'Read',
            ),
          ),
          Expanded(
            child: _buildToggleButton(
              context,
              mode: StudyViewMode.reflect,
              icon: Icons.edit_note_outlined,
              label: 'Reflect',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(
    BuildContext context, {
    required StudyViewMode mode,
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    final isSelected = currentMode == mode;

    return GestureDetector(
      onTap: () => onModeChanged(mode),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : theme.colorScheme.onBackground.withOpacity(0.6),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppFonts.inter(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onBackground.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
