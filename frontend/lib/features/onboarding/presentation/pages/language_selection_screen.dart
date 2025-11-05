import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
      // FIX: Mark language selection as completed BEFORE saving
      // This ensures the flag is set before any cache invalidation happens
      await _languageService.markLanguageSelectionCompleted();

      // Save language preference (this will cache completion state before invalidating caches)
      await _languageService.saveLanguagePreference(_selectedLanguage!);

      // FIX: Small delay to ensure all async operations complete before navigation
      // This prevents race condition with router guard checking language completion
      await Future.delayed(const Duration(milliseconds: 100));

      // Navigate to home screen
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      // Show error but still navigate to prevent user from being stuck
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(TranslationKeys.onboardingLanguageSavedLocally),
              style: GoogleFonts.inter(),
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

  Future<void> _skipSelection() async {
    // For authenticated users, save default English preference instead of skipping
    // For anonymous users, allow skipping
    setState(() {
      _isLoading = true;
    });

    try {
      // Save default English preference
      await _languageService.saveLanguagePreference(AppLanguage.english);

      // Mark language selection as completed
      await _languageService.markLanguageSelectionCompleted();

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
              style: GoogleFonts.inter(),
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
                style: GoogleFonts.playfairDisplay(
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
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  height: 1.5,
                ),
              ),

              SizedBox(height: isLargeScreen ? 48 : 32),

              // Language selection header
              Text(
                context.tr(TranslationKeys.onboardingSelectLanguage),
                style: GoogleFonts.inter(
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
                          style: GoogleFonts.inter(
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
                    style: GoogleFonts.inter(
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
