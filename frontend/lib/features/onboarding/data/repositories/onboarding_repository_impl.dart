import '../../domain/entities/onboarding_state_entity.dart';
import '../../domain/repositories/onboarding_repository.dart';
import '../datasources/onboarding_local_datasource.dart';

/// Implementation of OnboardingRepository
class OnboardingRepositoryImpl implements OnboardingRepository {
  final OnboardingLocalDataSource _localDataSource;

  const OnboardingRepositoryImpl({
    required OnboardingLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  @override
  Future<OnboardingStateEntity> getOnboardingState() async {
    try {
      final model = await _localDataSource.getOnboardingState();
      return model.toEntity();
    } catch (e) {
      // Return default state if there's an error
      return const OnboardingStateEntity();
    }
  }

  @override
  Future<void> saveLanguagePreference(String languageCode) async {
    await _localDataSource.saveLanguagePreference(languageCode);
  }

  @override
  Future<void> completeOnboarding() async {
    await _localDataSource.completeOnboarding();
  }

  @override
  Future<void> resetOnboarding() async {
    await _localDataSource.resetOnboarding();
  }
}