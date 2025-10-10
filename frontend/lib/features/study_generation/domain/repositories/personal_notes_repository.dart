import '../../../../core/services/personal_notes_api_service.dart';

/// Repository interface for personal notes operations
///
/// This repository follows Clean Architecture principles, defining the contract
/// for personal notes operations without exposing implementation details.
abstract class PersonalNotesRepository {
  /// Update personal notes for a study guide
  ///
  /// If the study guide is not saved, it will be saved automatically.
  /// Pass null for [notes] to delete existing notes.
  Future<PersonalNotesResponse> updatePersonalNotes({
    required String studyGuideId,
    required String? notes,
  });

  /// Get personal notes for a study guide
  Future<PersonalNotesResponse> getPersonalNotes({
    required String studyGuideId,
  });

  /// Delete personal notes for a study guide
  Future<PersonalNotesResponse> deletePersonalNotes({
    required String studyGuideId,
  });
}
