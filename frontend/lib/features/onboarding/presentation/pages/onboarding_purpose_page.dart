import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/onboarding_state_entity.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_event.dart';
import '../bloc/onboarding_state.dart';

class OnboardingPurposePage extends StatelessWidget {
  const OnboardingPurposePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) =>
            sl<OnboardingBloc>()..add(const LoadOnboardingState()),
        child: const _OnboardingPurposeContent(),
      );
}

class _OnboardingPurposeContent extends StatelessWidget {
  const _OnboardingPurposeContent();

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
              context.go('/onboarding');
              break;
            case OnboardingStep.language:
              context.go('/onboarding/language');
              break;
            case OnboardingStep.completed:
              context.go('/login');
              break;
            default:
              break;
          }
        } else if (state is OnboardingCompleted) {
          // Navigate to login when onboarding is completed
          context.go('/login');

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Setup complete! Please sign in to start your spiritual journey.'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 3),
            ),
          );
        } else if (state is OnboardingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Something went wrong. Please try again.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.read<OnboardingBloc>().add(const PreviousStep()),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Spacer(),

                // Illustration
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 80,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(height: 16),
                      Icon(
                        Icons.book,
                        size: 40,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                Text(
                  l10n.onboardingPurposeTitle,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                Text(
                  l10n.onboardingPurposeSubtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 48),

                // How it works
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How it works:',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        const _StepItem(
                          number: '1',
                          title: 'Choose Input',
                          description:
                              'Enter a Bible verse or topic you want to study',
                        ),
                        const SizedBox(height: 12),
                        const _StepItem(
                          number: '2',
                          title: 'AI Generation',
                          description:
                              'Our AI creates a detailed study guide using  methodology',
                        ),
                        const SizedBox(height: 12),
                        const _StepItem(
                          number: '3',
                          title: 'Study & Apply',
                          description:
                              'Follow the structured guide for deeper understanding and application',
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                BlocBuilder<OnboardingBloc, OnboardingState>(
                  builder: (context, state) {
                    final isLoading = state is OnboardingLoading;

                    return ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () => context
                              .read<OnboardingBloc>()
                              .add(const CompleteOnboardingRequested()),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      child: isLoading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Setting up...'),
                              ],
                            )
                          : const Text('Complete Setup'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _StepItem({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      );
}
