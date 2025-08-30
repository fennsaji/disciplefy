import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/services/api_auth_helper.dart';
import '../../domain/entities/study_guide.dart';

/// Abstract contract for remote study guide operations.
abstract class StudyRemoteDataSource {
  /// Generates a study guide using remote API.
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  /// Throws [RateLimitException] if rate limit is exceeded.
  Future<StudyGuide> generateStudyGuide({
    required String input,
    required String inputType,
    required String language,
  });
}

/// Implementation of StudyRemoteDataSource using Supabase.
class StudyRemoteDataSourceImpl implements StudyRemoteDataSource {
  /// Supabase client for API calls.
  final SupabaseClient _supabaseClient;

  /// UUID generator for creating unique IDs.
  final Uuid _uuid = const Uuid();

  /// Creates a new StudyRemoteDataSourceImpl instance.
  StudyRemoteDataSourceImpl({
    required SupabaseClient supabaseClient,
  }) : _supabaseClient = supabaseClient;

  @override
  Future<StudyGuide> generateStudyGuide({
    required String input,
    required String inputType,
    required String language,
  }) async {
    try {
      // Use unified authentication helper
      final headers = await ApiAuthHelper.getAuthHeaders();

      // Call Supabase Edge Function for study generation
      final response = await _supabaseClient.functions.invoke(
        'study-generate',
        body: {
          'input_type': inputType,
          'input_value': input,
          'language': language,
        },
        headers: headers,
      );

      if (response.status == 200 && response.data != null) {
        return _parseStudyGuideFromResponse(
            response.data, input, inputType, language);
      } else if (response.status == 429) {
        throw const RateLimitException(
          message:
              'You have reached your study generation limit. Please try again later.',
          code: 'RATE_LIMITED',
        );
      } else if (response.status >= 500) {
        throw const ServerException(
          message: 'Server error occurred. Please try again later.',
          code: 'SERVER_ERROR',
        );
      } else if (response.status == 401) {
        throw const AuthenticationException(
          message: 'Authentication required. Please sign in to continue.',
          code: 'UNAUTHORIZED',
        );
      } else {
        throw const ServerException(
          message: 'Failed to generate study guide. Please try again later.',
          code: 'GENERATION_FAILED',
        );
      }
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw ClientException(
        message: 'We couldn\'t generate a study guide. Please try again later.',
        code: 'GENERATION_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  /// Parses a study guide from the API response.
  ///
  /// Handles both enhanced responses (with personal_notes and isSaved)
  /// and legacy responses for backward compatibility.
  StudyGuide _parseStudyGuideFromResponse(
    Map<String, dynamic> data,
    String input,
    String inputType,
    String language,
  ) {
    final responseData = data['data'] as Map<String, dynamic>? ?? {};
    final studyGuide =
        responseData['study_guide'] as Map<String, dynamic>? ?? {};
    final content = studyGuide['content'] as Map<String, dynamic>? ?? {};

    // Extract enhanced fields (personal_notes and isSaved) if available
    final personalNotes = studyGuide['personal_notes'] as String?;
    final isSaved = studyGuide['isSaved'] as bool?;

    return StudyGuide(
      id: studyGuide['id'] as String? ?? _uuid.v4(),
      input: input, // Always use the original user input
      inputType: inputType, // Always use the original input type
      summary: content['summary'] as String? ?? 'No summary available',
      interpretation:
          content['interpretation'] as String? ?? 'No interpretation available',
      context: content['context'] as String? ?? 'No context available',
      relatedVerses: (content['relatedVerses'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      reflectionQuestions: (content['reflectionQuestions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      prayerPoints: (content['prayerPoints'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      language: language, // Always use the original language parameter
      createdAt: DateTime.parse(studyGuide['createdAt'] as String? ??
          DateTime.now().toIso8601String()),
      personalNotes: personalNotes, // Enhanced field
      isSaved: isSaved, // Enhanced field
    );
  }
}
