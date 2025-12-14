import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/auth_state_provider.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../domain/entities/user_level.dart';
import '../../domain/repositories/gamification_repository.dart';
import 'gamification_event.dart';
import 'gamification_state.dart';

class GamificationBloc extends Bloc<GamificationEvent, GamificationState> {
  final GamificationRepository _repository;
  final AuthStateProvider _authStateProvider;
  final LanguagePreferenceService _languagePreferenceService;

  GamificationBloc({
    required GamificationRepository repository,
    required AuthStateProvider authStateProvider,
    required LanguagePreferenceService languagePreferenceService,
  })  : _repository = repository,
        _authStateProvider = authStateProvider,
        _languagePreferenceService = languagePreferenceService,
        super(const GamificationState()) {
    on<LoadGamificationStats>(_onLoadStats);
    on<RefreshGamificationStats>(_onRefreshStats);
    on<UpdateStudyStreak>(_onUpdateStudyStreak);
    on<CheckStudyAchievements>(_onCheckStudyAchievements);
    on<CheckMemoryAchievements>(_onCheckMemoryAchievements);
    on<CheckVoiceAchievements>(_onCheckVoiceAchievements);
    on<CheckSavedAchievements>(_onCheckSavedAchievements);
    on<DismissAchievementNotification>(_onDismissNotification);
    on<ClearAllAchievementNotifications>(_onClearAllNotifications);
  }

  /// Get current user ID from auth provider
  String? get _userId => _authStateProvider.userId;

  /// Get current language code from language preference service
  /// Returns 'en' as default, actual language loaded asynchronously
  Future<String> _getLanguageCode() async {
    final language = await _languagePreferenceService.getSelectedLanguage();
    return language.code;
  }

  Future<void> _onLoadStats(
    LoadGamificationStats event,
    Emitter<GamificationState> emit,
  ) async {
    final userId = _userId;
    if (userId == null) {
      emit(state.copyWith(
        status: GamificationStatus.error,
        errorMessage: 'User not authenticated',
      ));
      return;
    }

    final languageCode = await _getLanguageCode();

    // Don't reload if already loaded, same user, same language, and not forcing refresh
    if (!event.forceRefresh &&
        state.status == GamificationStatus.loaded &&
        state.userId == userId &&
        state.languageCode == languageCode) {
      return;
    }

    emit(state.copyWith(
      status: GamificationStatus.loading,
      userId: userId,
      languageCode: languageCode,
    ));

    // Load stats and achievements in parallel
    final statsResult = await _repository.getUserStats(userId);
    final achievementsResult = await _repository.getUserAchievements(
      userId,
      languageCode,
    );

    statsResult.fold(
      (failure) => emit(state.copyWith(
        status: GamificationStatus.error,
        errorMessage: failure.message,
      )),
      (stats) {
        achievementsResult.fold(
          (failure) => emit(state.copyWith(
            status: GamificationStatus.error,
            errorMessage: failure.message,
          )),
          (achievements) {
            // Calculate level from XP
            final level = UserLevel.fromXp(stats.totalXp, languageCode);

            emit(state.copyWith(
              status: GamificationStatus.loaded,
              stats: stats,
              level: level,
              achievements: achievements,
            ));
          },
        );
      },
    );
  }

  Future<void> _onRefreshStats(
    RefreshGamificationStats event,
    Emitter<GamificationState> emit,
  ) async {
    add(const LoadGamificationStats(forceRefresh: true));
  }

  Future<void> _onUpdateStudyStreak(
    UpdateStudyStreak event,
    Emitter<GamificationState> emit,
  ) async {
    final userId = _userId;
    if (userId == null) return;

    final result = await _repository.updateStudyStreak(userId);

    result.fold(
      (failure) {
        // Silent failure - don't show error for streak update
      },
      (streakUpdate) {
        emit(state.copyWith(lastStreakUpdate: streakUpdate));

        // Also check for streak achievements
        add(const CheckStudyAchievements());
      },
    );
  }

  Future<void> _onCheckStudyAchievements(
    CheckStudyAchievements event,
    Emitter<GamificationState> emit,
  ) async {
    final userId = _userId;
    if (userId == null) return;

    final result = await _repository.checkAllStudyRelatedAchievements(userId);

    result.fold(
      (failure) {
        // Silent failure
      },
      (newAchievements) {
        if (newAchievements.isNotEmpty) {
          // Filter only new achievements
          final newOnly = newAchievements.where((a) => a.isNew).toList();
          if (newOnly.isNotEmpty) {
            // Add to pending notifications
            final updatedNotifications = [
              ...state.pendingNotifications,
              ...newOnly,
            ];
            emit(state.copyWith(pendingNotifications: updatedNotifications));
          }

          // Refresh stats to update counts
          add(const RefreshGamificationStats());
        }
      },
    );
  }

  Future<void> _onCheckMemoryAchievements(
    CheckMemoryAchievements event,
    Emitter<GamificationState> emit,
  ) async {
    final userId = _userId;
    if (userId == null) return;

    final result = await _repository.checkMemoryAchievements(userId);

    result.fold(
      (failure) {
        // Silent failure
      },
      (newAchievements) {
        if (newAchievements.isNotEmpty) {
          final newOnly = newAchievements.where((a) => a.isNew).toList();
          if (newOnly.isNotEmpty) {
            final updatedNotifications = [
              ...state.pendingNotifications,
              ...newOnly,
            ];
            emit(state.copyWith(pendingNotifications: updatedNotifications));
          }
          add(const RefreshGamificationStats());
        }
      },
    );
  }

  Future<void> _onCheckVoiceAchievements(
    CheckVoiceAchievements event,
    Emitter<GamificationState> emit,
  ) async {
    final userId = _userId;
    if (userId == null) return;

    final result = await _repository.checkVoiceAchievements(userId);

    result.fold(
      (failure) {
        // Silent failure
      },
      (newAchievements) {
        if (newAchievements.isNotEmpty) {
          final newOnly = newAchievements.where((a) => a.isNew).toList();
          if (newOnly.isNotEmpty) {
            final updatedNotifications = [
              ...state.pendingNotifications,
              ...newOnly,
            ];
            emit(state.copyWith(pendingNotifications: updatedNotifications));
          }
          add(const RefreshGamificationStats());
        }
      },
    );
  }

  Future<void> _onCheckSavedAchievements(
    CheckSavedAchievements event,
    Emitter<GamificationState> emit,
  ) async {
    final userId = _userId;
    if (userId == null) return;

    final result = await _repository.checkSavedAchievements(userId);

    result.fold(
      (failure) {
        // Silent failure
      },
      (newAchievements) {
        if (newAchievements.isNotEmpty) {
          final newOnly = newAchievements.where((a) => a.isNew).toList();
          if (newOnly.isNotEmpty) {
            final updatedNotifications = [
              ...state.pendingNotifications,
              ...newOnly,
            ];
            emit(state.copyWith(pendingNotifications: updatedNotifications));
          }
          add(const RefreshGamificationStats());
        }
      },
    );
  }

  void _onDismissNotification(
    DismissAchievementNotification event,
    Emitter<GamificationState> emit,
  ) {
    if (state.pendingNotifications.isEmpty) return;

    // Remove the first notification (FIFO)
    final updatedNotifications = state.pendingNotifications.skip(1).toList();
    emit(state.copyWith(pendingNotifications: updatedNotifications));
  }

  void _onClearAllNotifications(
    ClearAllAchievementNotifications event,
    Emitter<GamificationState> emit,
  ) {
    emit(state.copyWith(pendingNotifications: []));
  }
}
