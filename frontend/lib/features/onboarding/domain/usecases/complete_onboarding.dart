import '../repositories/onboarding_repository.dart';

/// Use case for completing the onboarding process
class CompleteOnboarding {
  final OnboardingRepository _repository;

  const CompleteOnboarding(this._repository);

  /// Marks the onboarding process as completed
  Future<void> call() async {
    await _repository.completeOnboarding();
  }
}