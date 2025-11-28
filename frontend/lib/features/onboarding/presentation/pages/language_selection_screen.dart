import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';

import '../../../../core/models/app_language.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../../../core/di/injection_container.dart';
import '../widgets/language_selection_card.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';

/// Screen for selecting preferred language during onboarding
class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  AppLanguage? _selectedLanguage;
  bool _isLoading = false;

  final LanguagePreferenceService _languageService =
      sl<LanguagePreferenceService>();

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
  }

  Future<void> _loadCurrentLanguage() async {
    try {
      final currentLanguage = await _languageService.getSelectedLanguage();
      if (mounted) {
        setState(() {
          _selectedLanguage = currentLanguage;
        });
      }
    } catch (e) {
      // Default to English if there's an error
      if (mounted) {
        setState(() {
          _selectedLanguage = AppLanguage.english;
        });
      }
    }
  }

  void _selectLanguage(AppLanguage language) {
    setState(() {
      _selectedLanguage = language;
    });
  }

  Future<void> _continueWithSelection() async {
    if (_selectedLanguage == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Save language preference - this will update the database AND mark completion
      // The service handles marking completion internally only after successful DB save
      await _languageService.saveLanguagePreference(_selectedLanguage!);

      // Verify that persistence and cache invalidation completed successfully
      final bool persistenceVerified =
          await _languageService.hasCompletedLanguageSelection();

      if (!persistenceVerified) {
        throw Exception(
            'Language preference persistence verification failed. Please try again.');
      }

      // Navigate to home screen only after successful verification
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      // Show error and do NOT navigate - allow user to retry
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save language preference: ${e.toString()}',
              style: AppFonts.inter(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _skipSelection() async {
    // For authenticated users, save default English preference instead of skipping
    // For anonymous users, allow skipping
    setState(() {
      _isLoading = true;
    });

    try {
      // Save default English preference - service handles marking completion internally
      await _languageService.saveLanguagePreference(AppLanguage.english);

      // Navigate to home screen
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(TranslationKeys.onboardingDefaultLanguageSet),
              style: AppFonts.inter(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
        context.go('/');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenHeight > 700;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top spacing
              SizedBox(height: isLargeScreen ? 60 : 40),

              // Welcome text
              Text(
                context.tr(TranslationKeys.onboardingWelcome),
                style: AppFonts.poppins(
                  fontSize: isLargeScreen ? 32 : 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  height: 1.2,
                ),
              ),

              SizedBox(height: isLargeScreen ? 16 : 12),

              // Subtitle
              Text(
                context.tr(TranslationKeys.onboardingSelectLanguageSubtitle),
                style: AppFonts.inter(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  height: 1.5,
                ),
              ),

              SizedBox(height: isLargeScreen ? 48 : 32),

              // Language selection header
              Text(
                context.tr(TranslationKeys.onboardingSelectLanguage),
                style: AppFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 24),

              // Language options
              Expanded(
                child: ListView.builder(
                  itemCount: AppLanguage.all.length,
                  itemBuilder: (context, index) {
                    final language = AppLanguage.all[index];
                    return LanguageSelectionCard(
                      language: language,
                      isSelected: _selectedLanguage == language,
                      onTap: () => _selectLanguage(language),
                    );
                  },
                ),
              ),

              // Bottom section with buttons
              const SizedBox(height: 24),

              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedLanguage != null && !_isLoading
                      ? _continueWithSelection
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        theme.colorScheme.onSurface.withOpacity(0.12),
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          context.tr(TranslationKeys.onboardingContinue),
                          style: AppFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Skip button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isLoading ? null : _skipSelection,
                  style: TextButton.styleFrom(
                    foregroundColor:
                        theme.colorScheme.onSurface.withOpacity(0.6),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    context.tr(TranslationKeys.onboardingSkip),
                    style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
