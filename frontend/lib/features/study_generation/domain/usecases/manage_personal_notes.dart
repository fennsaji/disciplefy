import '../../../../core/services/personal_notes_api_service.dart';
import '../repositories/personal_notes_repository.dart';

/// Use case for managing personal notes on study guides
///
/// This use case encapsulates all personal notes business logic and follows
/// Clean Architecture principles by depending only on the repository interface.
///
/// Features:
/// - Update/create personal notes
/// - Retrieve existing notes
/// - Delete notes
/// - Consistent error handling
/// - Business rule enforcement
class ManagePersonalNotesUseCase {
  final PersonalNotesRepository _repository;

  ManagePersonalNotesUseCase({
    required PersonalNotesRepository repository,
  }) : _repository = repository;

  /// Update personal notes for a study guide
  ///
  /// Business rules:
  /// - If the study guide is not saved, it will be saved automatically
  /// - Pass null for [notes] to delete existing notes
  /// - Empty strings are treated as deletion requests
  Future<PersonalNotesResponse> updatePersonalNotes({
    required String studyGuideId,
    required String? notes,
  }) async {
    // Business rule: treat empty strings as deletion
    final normalizedNotes =
        (notes?.trim().isEmpty ?? true) ? null : notes?.trim();

    return await _repository.updatePersonalNotes(
      studyGuideId: studyGuideId,
      notes: normalizedNotes,
    );
  }

  /// Get personal notes for a study guide
  Future<PersonalNotesResponse> getPersonalNotes({
    required String studyGuideId,
  }) async {
    return await _repository.getPersonalNotes(
      studyGuideId: studyGuideId,
    );
  }

  /// Delete personal notes for a study guide
  Future<PersonalNotesResponse> deletePersonalNotes({
    required String studyGuideId,
  }) async {
    return await _repository.deletePersonalNotes(
      studyGuideId: studyGuideId,
    );
  }

  /// Check if a study guide has personal notes
  Future<bool> hasPersonalNotes({
    required String studyGuideId,
  }) async {
    try {
      final response = await _repository.getPersonalNotes(
        studyGuideId: studyGuideId,
      );

      return response.success &&
          response.notes != null &&
          response.notes!.trim().isNotEmpty;
    } catch (e) {
      // If there's an error, assume no notes exist
      return false;
    }
  }
}
