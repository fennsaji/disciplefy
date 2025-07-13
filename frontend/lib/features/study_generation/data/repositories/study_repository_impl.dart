import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/study_guide.dart';
import '../../domain/repositories/study_repository.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/api_auth_helper.dart';

/// Implementation of the StudyRepository interface.
/// 
/// This class handles study guide generation, caching, and retrieval
/// using Supabase as the backend and Hive for local caching.
class StudyRepositoryImpl implements StudyRepository {
  /// Supabase client for API calls.
  final SupabaseClient _supabaseClient;
  
  /// Network information service.
  final NetworkInfo _networkInfo;
  
  /// UUID generator for creating unique IDs.
  final Uuid _uuid = const Uuid();
  
  /// Box name for caching study guides.
  static const String _studyGuidesBoxName = 'study_guides';

  /// Creates a new StudyRepositoryImpl instance.
  /// 
  /// [supabaseClient] The Supabase client for API calls.
  /// [networkInfo] The network information service.
  StudyRepositoryImpl({
    required SupabaseClient supabaseClient,
    required NetworkInfo networkInfo,
  })  : _supabaseClient = supabaseClient,
        _networkInfo = networkInfo;

  @override
  Future<Either<Failure, StudyGuide>> generateStudyGuide({
    required String input,
    required String inputType,
    required String language,
  }) async {
    try {
      // Check network connectivity
      if (!await _networkInfo.isConnected) {
        return const Left(NetworkFailure(
          message: 'No internet connection. Please check your network and try again.',
          code: 'NO_CONNECTION',
        ));
      }

      // Get authentication context
      final userContext = await _getUserContext();
      
      // Use unified authentication helper
      final headers = await ApiAuthHelper.getAuthHeaders();

      // Call Supabase Edge Function for study generation
      final response = await _supabaseClient.functions.invoke(
        'study-generate',
        body: {
          'input_type': inputType,
          'input_value': input,
          'language': language,
          'user_context': userContext,
        },
        headers: headers,
      );

      if (response.status == 200 && response.data != null) {
        final studyGuide = _parseStudyGuideFromResponse(response.data, input, inputType, language);
        
        // Cache the generated study guide
        await cacheStudyGuide(studyGuide);
        
        return Right(studyGuide);
      } else if (response.status == 429) {
        return const Left(RateLimitFailure(
          message: 'You have reached your study generation limit. Please try again later.',
          code: 'RATE_LIMITED',
        ));
      } else if (response.status >= 500) {
        return const Left(ServerFailure(
          
        ));
      } else {
        return const Left(ServerFailure(
          message: 'Failed to generate study guide. Please try again later.',
          code: 'GENERATION_FAILED',
        ));
      }
    } on NetworkException catch (e) {
      return Left(NetworkFailure(
        message: e.message,
        code: e.code,
        context: e.context,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(
        message: e.message,
        code: e.code,
        context: e.context,
      ));
    } catch (e) {
      return Left(ClientFailure(
        message: 'We couldn\'t generate a study guide. Please try again later.',
        code: 'GENERATION_FAILED',
        context: {'originalError': e.toString()},
      ));
    }
  }

  @override
  Future<List<StudyGuide>> getCachedStudyGuides() async {
    try {
      if (!Hive.isBoxOpen(_studyGuidesBoxName)) {
        await Hive.openBox(_studyGuidesBoxName);
      }
      
      final box = Hive.box(_studyGuidesBoxName);
      final studyGuides = <StudyGuide>[];
      
      for (final key in box.keys) {
        final data = box.get(key) as Map<dynamic, dynamic>?;
        if (data != null) {
          try {
            final studyGuide = _parseStudyGuideFromCache(data);
            studyGuides.add(studyGuide);
          } catch (e) {
            // Skip invalid cached entries
            continue;
          }
        }
      }
      
      // Sort by creation date (newest first)
      studyGuides.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Return only the most recent guides
      return studyGuides.take(AppConstants.MAX_STUDY_GUIDES_CACHE).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<bool> cacheStudyGuide(StudyGuide studyGuide) async {
    try {
      if (!Hive.isBoxOpen(_studyGuidesBoxName)) {
        await Hive.openBox(_studyGuidesBoxName);
      }
      
      final box = Hive.box(_studyGuidesBoxName);
      final data = _convertStudyGuideToMap(studyGuide);
      
      await box.put(studyGuide.id, data);
      
      // Cleanup old entries if cache exceeds limit
      if (box.length > AppConstants.MAX_STUDY_GUIDES_CACHE) {
        final allGuides = await getCachedStudyGuides();
        final oldestGuides = allGuides.skip(AppConstants.MAX_STUDY_GUIDES_CACHE);
        
        for (final guide in oldestGuides) {
          await box.delete(guide.id);
        }
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> clearCache() async {
    try {
      if (!Hive.isBoxOpen(_studyGuidesBoxName)) {
        await Hive.openBox(_studyGuidesBoxName);
      }
      
      final box = Hive.box(_studyGuidesBoxName);
      await box.clear();
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Parses a study guide from the API response.
  /// Updated to handle new cached architecture response format.
  StudyGuide _parseStudyGuideFromResponse(
    Map<String, dynamic> data,
    String input,
    String inputType,
    String language,
  ) {
    final responseData = data['data'] as Map<String, dynamic>? ?? {};
    final studyGuide = responseData['study_guide'] as Map<String, dynamic>? ?? {};
    final content = studyGuide['content'] as Map<String, dynamic>? ?? {};
    final inputData = studyGuide['input'] as Map<String, dynamic>? ?? {};
    
    return StudyGuide(
      id: studyGuide['id'] as String? ?? _uuid.v4(),
      input: inputData['value'] as String? ?? input,
      inputType: inputData['type'] as String? ?? inputType,
      summary: content['summary'] as String? ?? 'No summary available',
      interpretation: content['interpretation'] as String? ?? 'No interpretation available',
      context: content['context'] as String? ?? 'No context available',
      relatedVerses: (content['relatedVerses'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      reflectionQuestions: (content['reflectionQuestions'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      prayerPoints: (content['prayerPoints'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      language: inputData['language'] as String? ?? language,
      createdAt: DateTime.parse(studyGuide['createdAt'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  /// Parses a study guide from cached data.
  StudyGuide _parseStudyGuideFromCache(Map<dynamic, dynamic> data) => StudyGuide(
      id: data['id'] as String,
      input: data['input'] as String,
      inputType: data['inputType'] as String,
      summary: data['summary'] as String,
      interpretation: data['interpretation'] as String? ?? 'No interpretation available',
      context: data['context'] as String,
      relatedVerses: (data['relatedVerses'] as List<dynamic>).map((e) => e.toString()).toList(),
      reflectionQuestions: (data['reflectionQuestions'] as List<dynamic>).map((e) => e.toString()).toList(),
      prayerPoints: (data['prayerPoints'] as List<dynamic>).map((e) => e.toString()).toList(),
      language: data['language'] as String? ?? AppConstants.DEFAULT_LANGUAGE,
      createdAt: DateTime.parse(data['createdAt'] as String),
      userId: data['userId'] as String?,
    );

  /// Converts a study guide to a map for caching.
  Map<String, dynamic> _convertStudyGuideToMap(StudyGuide studyGuide) => {
      'id': studyGuide.id,
      'input': studyGuide.input,
      'inputType': studyGuide.inputType,
      'summary': studyGuide.summary,
      'interpretation': studyGuide.interpretation,
      'context': studyGuide.context,
      'relatedVerses': studyGuide.relatedVerses,
      'reflectionQuestions': studyGuide.reflectionQuestions,
      'prayerPoints': studyGuide.prayerPoints,
      'language': studyGuide.language,
      'createdAt': studyGuide.createdAt.toIso8601String(),
      'userId': studyGuide.userId,
    };

  /// Gets the user context for API requests.
  Future<Map<String, dynamic>> _getUserContext() async {
    try {
      // Use ApiAuthHelper for consistent authentication state
      if (ApiAuthHelper.isAuthenticated) {
        final userId = ApiAuthHelper.currentUserId;
        return {
          'is_authenticated': true,
          'user_id': userId,
        };
      } else {
        // For anonymous users, create or get a session ID
        final sessionId = await _getOrCreateSessionId();
        return {
          'is_authenticated': false,
          'session_id': sessionId,
        };
      }
    } catch (e) {
      // Fallback to anonymous session
      final sessionId = await _getOrCreateSessionId();
      return {
        'is_authenticated': false,
        'session_id': sessionId,
      };
    }
  }

  /// Gets or creates a session ID for anonymous users.
  Future<String> _getOrCreateSessionId() async {
    try {
      if (!Hive.isBoxOpen('app_settings')) {
        await Hive.openBox('app_settings');
      }
      
      final box = Hive.box('app_settings');
      String? sessionId = box.get('anonymous_session_id');
      
      if (sessionId == null || sessionId.isEmpty) {
        sessionId = _uuid.v4();
        await box.put('anonymous_session_id', sessionId);
      }
      
      return sessionId;
    } catch (e) {
      // Fallback to generating a new session ID
      return _uuid.v4();
    }
  }

}