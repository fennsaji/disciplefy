import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    // Use consistent authentication check with router (Supabase)
    final user = Supabase.instance.client.auth.currentUser;
    final isAuthenticated = user != null;
    final isAnonymous = user?.isAnonymous ?? true;
    
    // Also check AuthService for compatibility
    final userType = await AuthService.getUserType();
    final hasStoredToken = await AuthService.getAuthToken() != null;
    
    // Debug authentication state
    print('🔐 [SAVED_GUIDES] Auth Debug:');
    print('  - Supabase isAuthenticated: $isAuthenticated');
    print('  - Supabase isAnonymous: $isAnonymous');
    print('  - Supabase user email: ${user?.email ?? "none"}');
    print('  - AuthService userType: $userType');
    print('  - AuthService hasToken: $hasStoredToken');
    
    // Require proper authentication (not anonymous)
    if (!isAuthenticated || isAnonymous) {
      print('❌ [SAVED_GUIDES] User needs authentication - not properly signed in');
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
    // Use consistent authentication check with router (Supabase)
    final user = Supabase.instance.client.auth.currentUser;
    final isAuthenticated = user != null;
    final isAnonymous = user?.isAnonymous ?? true;
    
    if (!isAuthenticated || isAnonymous) {
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
    // Don't dispose the API service here since it might be shared
    // _apiService.dispose();
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
  
  factory StudyGuidesResult.success(List<SavedGuideModel> guides) => StudyGuidesResult._(
      guides: guides,
      isSuccess: true,
    );
  
  factory StudyGuidesResult.error(String error) => StudyGuidesResult._(
      error: error,
    );
  
  factory StudyGuidesResult.authRequired() => const StudyGuidesResult._(
      requiresAuth: true,
    );
}