import '../entities/onboarding_state_entity.dart';
import '../repositories/onboarding_repository.dart';

/// Use case for retrieving the current onboarding state
class GetOnboardingState {
  final OnboardingRepository _repository;

  const GetOnboardingState(this._repository);

  /// Retrieves the current onboarding state
  Future<OnboardingStateEntity> call() async =>
      await _repository.getOnboardingState();
}
