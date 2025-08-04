import '../models/saved_guide_model.dart';
import '../services/study_guides_api_service.dart';

/// Abstract interface for remote data source operations
abstract class SavedGuidesRemoteDataSource {
  /// Fetch saved guides from the API
  Future<List<SavedGuideModel>> getSavedGuides({
    int limit = 20,
    int offset = 0,
  });

  /// Fetch recent guides from the API
  Future<List<SavedGuideModel>> getRecentGuides({
    int limit = 20,
    int offset = 0,
  });

  /// Toggle save/unsave a guide via API
  Future<SavedGuideModel> toggleSaveGuide({
    required String guideId,
    required bool save,
  });
}

/// Implementation of remote data source using the API service
class SavedGuidesRemoteDataSourceImpl implements SavedGuidesRemoteDataSource {
  final StudyGuidesApiService _apiService;

  const SavedGuidesRemoteDataSourceImpl({
    required StudyGuidesApiService apiService,
  }) : _apiService = apiService;

  @override
  Future<List<SavedGuideModel>> getSavedGuides({
    int limit = 20,
    int offset = 0,
  }) async =>
      await _apiService.getStudyGuides(
        savedOnly: true,
        limit: limit,
        offset: offset,
      );

  @override
  Future<List<SavedGuideModel>> getRecentGuides({
    int limit = 20,
    int offset = 0,
  }) async =>
      await _apiService.getStudyGuides(
        limit: limit,
        offset: offset,
      );

  @override
  Future<SavedGuideModel> toggleSaveGuide({
    required String guideId,
    required bool save,
  }) async =>
      await _apiService.saveUnsaveGuide(
        guideId: guideId,
        save: save,
      );
}
