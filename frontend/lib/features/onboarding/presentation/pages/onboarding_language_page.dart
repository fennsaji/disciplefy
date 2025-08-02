import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/onboarding_state_entity.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_event.dart';
import '../bloc/onboarding_state.dart';

class OnboardingLanguagePage extends StatelessWidget {
  const OnboardingLanguagePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
      create: (context) => sl<OnboardingBloc>()..add(const LoadOnboardingState()),
      child: const _OnboardingLanguageContent(),
    );
}

class _OnboardingLanguageContent extends StatelessWidget {
  const _OnboardingLanguageContent();

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

    return BlocListener<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state is OnboardingNavigating) {
          // Navigate based on the navigation state
          switch (state.toStep) {
            case OnboardingStep.welcome:
            case OnboardingStep.purpose:
            case OnboardingStep.completed:
              context.go('/');
              break;
            default:
              break;
          }
        } else if (state is OnboardingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.read<OnboardingBloc>().add(const PreviousStep()),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: BlocBuilder<OnboardingBloc, OnboardingState>(
              builder: (context, state) {
                if (state is OnboardingLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final selectedLanguage = state is OnboardingLoaded 
                    ? state.onboardingState.selectedLanguage ?? 'en'
                    : 'en';

                return Column(
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
                      isSelected: selectedLanguage == 'en',
                      onTap: () => context.read<OnboardingBloc>().add(const LanguageSelected('en')),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _LanguageOption(
                      code: 'hi',
                      name: l10n.languageHindi,
                      nativeName: 'हिन्दी',
                      isSelected: selectedLanguage == 'hi',
                      onTap: () => context.read<OnboardingBloc>().add(const LanguageSelected('hi')),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _LanguageOption(
                      code: 'ml',
                      name: l10n.languageMalayalam,
                      nativeName: 'മലയാളം',
                      isSelected: selectedLanguage == 'ml',
                      onTap: () => context.read<OnboardingBloc>().add(const LanguageSelected('ml')),
                    ),
                    
                    const Spacer(),
                    
                    ElevatedButton(
                      onPressed: selectedLanguage.isNotEmpty 
                          ? () => context.read<OnboardingBloc>().add(const NextStep())
                          : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      child: Text(l10n.continueButton),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
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