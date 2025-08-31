import '../../../../core/services/personal_notes_api_service.dart';
import '../../domain/repositories/personal_notes_repository.dart';

/// Concrete implementation of PersonalNotesRepository
///
/// This implementation follows Clean Architecture by:
/// - Implementing the domain repository interface
/// - Delegating to the data layer API service
/// - Handling data layer concerns (API calls, error handling)
class PersonalNotesRepositoryImpl implements PersonalNotesRepository {
  final PersonalNotesApiService _apiService;

  PersonalNotesRepositoryImpl({
    required PersonalNotesApiService apiService,
  }) : _apiService = apiService;

  @override
  Future<PersonalNotesResponse> updatePersonalNotes({
    required String studyGuideId,
    required String? notes,
  }) async {
    return await _apiService.updatePersonalNotes(
      studyGuideId: studyGuideId,
      notes: notes,
    );
  }

  @override
  Future<PersonalNotesResponse> getPersonalNotes({
    required String studyGuideId,
  }) async {
    return await _apiService.getPersonalNotes(
      studyGuideId: studyGuideId,
    );
  }

  @override
  Future<PersonalNotesResponse> deletePersonalNotes({
    required String studyGuideId,
  }) async {
    return await _apiService.deletePersonalNotes(
      studyGuideId: studyGuideId,
    );
  }
}
