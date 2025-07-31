import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/ui_constants.dart';

/// Language tabs for daily verse selection.
/// 
/// Allows users to switch between different language versions
/// of the daily verse (English, Hindi, Malayalam).
class VerseLanguageTabs extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;

  const VerseLanguageTabs({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: UIConstants.sectionMarginVertical,
      child: Row(
        children: [
          _buildLanguageTab(
            context: context,
            languageCode: 'en',
            label: '🇺🇸 English',
            isSelected: selectedLanguage == 'en',
            theme: theme,
          ),
          const SizedBox(width: UIConstants.spacingSm),
          _buildLanguageTab(
            context: context,
            languageCode: 'hi',
            label: '🇮🇳 हिन्दी',
            isSelected: selectedLanguage == 'hi',
            theme: theme,
          ),
          const SizedBox(width: UIConstants.spacingSm),
          _buildLanguageTab(
            context: context,
            languageCode: 'ml',
            label: '🇮🇳 മലയാളം',
            isSelected: selectedLanguage == 'ml',
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageTab({
    required BuildContext context,
    required String languageCode,
    required String label,
    required bool isSelected,
    required ThemeData theme,
  }) {
    // Calculate luminance for automatic contrast
    final backgroundColor = isSelected
        ? theme.colorScheme.secondary
        : theme.colorScheme.surface;
    final luminance = backgroundColor.computeLuminance();
    final textColor = luminance > 0.5 ? Colors.black87 : Colors.white;

    return Expanded(
      child: GestureDetector(
        onTap: () => onLanguageChanged(languageCode),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: UIConstants.languageTabPadding,
            horizontal: UIConstants.spacingSm,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: UIConstants.borderRadiusSm,
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: UIConstants.opacityOverlay)
                  : theme.colorScheme.outline.withValues(alpha: UIConstants.opacityLight),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: UIConstants.opacityLight),
                      blurRadius: UIConstants.elevationMd,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: UIConstants.fontSizeSm,
              fontWeight: isSelected ? UIConstants.fontWeightSemiBold : UIConstants.fontWeightMedium,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}