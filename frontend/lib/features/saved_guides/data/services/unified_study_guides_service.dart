import 'dart:async';
import '../../../../core/services/auth_service.dart';
import '../models/saved_guide_model.dart';
import 'study_guides_api_service.dart';

/// Unified service for fetching study guides with auth-aware logic
class UnifiedStudyGuidesService {
  final StudyGuidesApiService _apiService;
  
  UnifiedStudyGuidesService({StudyGuidesApiService? apiService}) 
      : _apiService = apiService ?? StudyGuidesApiService();

  /// Fetch study guides with auth-aware logic
  /// Returns guides for authenticated users, throws AuthException for guests
  Future<StudyGuidesResult> fetchStudyGuides({
    bool saved = false,
    int limit = 20,
    int offset = 0,
  }) async {
    // Check authentication status
    final isFullyAuthenticated = await AuthService.isFullyAuthenticated();
    final isGuest = await AuthService.isGuestUser();
    
    if (isGuest) {
      return StudyGuidesResult.authRequired();
    }
    
    if (!isFullyAuthenticated) {
      return StudyGuidesResult.authRequired();
    }
    
    try {
      final guides = await _apiService.getStudyGuides(
        savedOnly: saved,
        limit: limit,
        offset: offset,
      );
      
      return StudyGuidesResult.success(guides);
    } catch (e) {
      return StudyGuidesResult.error(e.toString());
    }
  }
  
  /// Save or unsave a study guide
  Future<StudyGuidesResult> toggleSaveGuide({
    required String guideId,
    required bool save,
  }) async {
    final isFullyAuthenticated = await AuthService.isFullyAuthenticated();
    final isGuest = await AuthService.isGuestUser();
    
    if (isGuest || !isFullyAuthenticated) {
      return StudyGuidesResult.authRequired();
    }
    
    try {
      final guide = await _apiService.saveUnsaveGuide(
        guideId: guideId,
        save: save,
      );
      
      return StudyGuidesResult.success([guide]);
    } catch (e) {
      return StudyGuidesResult.error(e.toString());
    }
  }
  
  void dispose() {
    _apiService.dispose();
  }
}

/// Result wrapper for study guides operations
class StudyGuidesResult {
  final List<SavedGuideModel>? guides;
  final String? error;
  final bool requiresAuth;
  final bool isSuccess;
  
  const StudyGuidesResult._({
    this.guides,
    this.error,
    this.requiresAuth = false,
    this.isSuccess = false,
  });
  
  factory StudyGuidesResult.success(List<SavedGuideModel> guides) {
    return StudyGuidesResult._(
      guides: guides,
      isSuccess: true,
    );
  }
  
  factory StudyGuidesResult.error(String error) {
    return StudyGuidesResult._(
      error: error,
      isSuccess: false,
    );
  }
  
  factory StudyGuidesResult.authRequired() {
    return const StudyGuidesResult._(
      requiresAuth: true,
      isSuccess: false,
    );
  }
}