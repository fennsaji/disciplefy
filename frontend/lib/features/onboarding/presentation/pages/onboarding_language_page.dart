import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/localization/app_localizations.dart';

class OnboardingLanguagePage extends StatefulWidget {
  const OnboardingLanguagePage({super.key});

  @override
  State<OnboardingLanguagePage> createState() => _OnboardingLanguagePageState();
}

class _OnboardingLanguagePageState extends State<OnboardingLanguagePage> {
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    // Check if user has previously selected a language
    _loadSelectedLanguage();
  }

  void _loadSelectedLanguage() async {
    final box = Hive.box('app_settings');
    final savedLanguage = box.get('selected_language', defaultValue: 'en');
    if (['en', 'hi', 'ml'].contains(savedLanguage)) {
      setState(() {
        _selectedLanguage = savedLanguage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    // If localization is not ready, show loading
    if (l10n == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/onboarding/welcome'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.onboardingLanguageTitle,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                l10n.onboardingLanguageSubtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Language Options
              _LanguageOption(
                code: 'en',
                name: l10n.languageEnglish,
                nativeName: 'English',
                isSelected: _selectedLanguage == 'en',
                onTap: () => setState(() => _selectedLanguage = 'en'),
              ),
              
              const SizedBox(height: 16),
              
              _LanguageOption(
                code: 'hi',
                name: l10n.languageHindi,
                nativeName: 'हिन्दी',
                isSelected: _selectedLanguage == 'hi',
                onTap: () => setState(() => _selectedLanguage = 'hi'),
              ),
              
              const SizedBox(height: 16),
              
              _LanguageOption(
                code: 'ml',
                name: l10n.languageMalayalam,
                nativeName: 'മലയാളം',
                isSelected: _selectedLanguage == 'ml',
                onTap: () => setState(() => _selectedLanguage = 'ml'),
              ),
              
              const Spacer(),
              
              ElevatedButton(
                onPressed: () => _continueWithLanguage(),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: Text(l10n.continueButton),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _continueWithLanguage() async {
    // Save selected language
    final box = Hive.box('app_settings');
    await box.put('selected_language', _selectedLanguage);
    
    if (mounted) {
      context.go('/onboarding/purpose');
    }
  }
}

class _LanguageOption extends StatelessWidget {
  final String code;
  final String name;
  final String nativeName;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected 
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  code.toUpperCase(),
                  style: TextStyle(
                    color: isSelected 
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  Text(
                    nativeName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
}