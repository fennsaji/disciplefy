import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/services/api_auth_helper.dart';
import '../../../../core/utils/rate_limiter.dart';
import '../../domain/entities/study_guide.dart';
import '../../../tokens/domain/entities/token_consumption.dart';
import '../../../../core/utils/logger.dart';

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
    String? topicDescription,
    required String language,
  });
}

/// Implementation of StudyRemoteDataSource using Supabase.
class StudyRemoteDataSourceImpl implements StudyRemoteDataSource {
  /// Supabase client for API calls.
  final SupabaseClient _supabaseClient;

  /// UUID generator for creating unique IDs.
  final Uuid _uuid = const Uuid();

  /// SECURITY FIX: Client-side rate limiter
  /// Limits to 5 requests per minute to prevent API abuse
  final RateLimiter _rateLimiter = RateLimiter(
    maxRequests: 5,
    window: const Duration(minutes: 1),
  );

  /// Creates a new StudyRemoteDataSourceImpl instance.
  StudyRemoteDataSourceImpl({
    required SupabaseClient supabaseClient,
  }) : _supabaseClient = supabaseClient;

  @override
  Future<StudyGuide> generateStudyGuide({
    required String input,
    required String inputType,
    String? topicDescription,
    required String language,
  }) async {
    Logger.info('🚨 [STUDY_API] Starting study generation request');

    // SECURITY FIX: Check client-side rate limit before making request
    if (!_rateLimiter.canMakeRequest()) {
      final retryAfter = _rateLimiter.getRetryAfter();
      final waitSeconds = retryAfter.inSeconds;

      Logger.debug('🚨 [STUDY_API] Rate limited: wait $waitSeconds seconds');

      throw RateLimitException(
        message:
            'Please wait $waitSeconds seconds before generating another study guide.',
        code: 'CLIENT_RATE_LIMITED',
        retryAfter: retryAfter,
      );
    }

    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      // Use unified authentication helper
      final headers = await ApiAuthHelper.getAuthHeaders();

      // Call Supabase Edge Function for study generation
      Logger.debug('🚨 [STUDY_API] Making API call to study-generate');
      final response = await _supabaseClient.functions.invoke(
        'study-generate',
        body: {
          'input_type': inputType,
          'input_value': input,
          if (topicDescription != null) 'topic_description': topicDescription,
          'language': language,
        },
        headers: headers,
      );

      Logger.info(
          '🚨 [STUDY_API] Received response status: ${response.status}');

      if (response.status == 200 && response.data != null) {
        return _parseStudyGuideFromResponse(
            response.data, input, inputType, language);
      } else if (response.status == 429) {
        // Debug logging for 429 response
        Logger.info('🚨 [STUDY_API] 429 Response data: ${response.data}');
        Logger.debug(
            '🚨 [STUDY_API] Response data type: ${response.data.runtimeType}');

        // Handle both old rate limiting and new token exhaustion
        final errorData = response.data as Map<String, dynamic>?;
        Logger.error('🚨 [STUDY_API] Parsed errorData: $errorData');
        final error = errorData?['error'] as Map<String, dynamic>?;
        Logger.error('🚨 [STUDY_API] Parsed error: $error');

        if (error?['code'] == 'INSUFFICIENT_TOKENS') {
          // New token-based error
          final details = error?['details'] as Map<String, dynamic>?;
          final required = details?['required'] as int? ?? 0;
          final available = details?['available'] as int? ?? 0;

          throw InsufficientTokensException(
            message:
                'You need $required tokens but only have $available available.',
            code: 'INSUFFICIENT_TOKENS',
            requiredTokens: required,
            availableTokens: available,
            nextResetTime: details?['next_reset'] != null
                ? DateTime.tryParse(details!['next_reset'] as String)
                : null,
          );
        } else {
          // Legacy rate limiting error
          throw const RateLimitException(
            message:
                'You have reached your study generation limit. Please try again later.',
            code: 'RATE_LIMITED',
          );
        }
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
    } on NetworkException catch (e) {
      Logger.debug('🚨 [STUDY_API] NetworkException caught: $e');
      rethrow;
    } on ServerException catch (e) {
      Logger.debug('🚨 [STUDY_API] ServerException caught: $e');
      rethrow;
    } on AuthenticationException catch (e) {
      Logger.debug('🚨 [STUDY_API] AuthenticationException caught: $e');
      rethrow;
    } on RateLimitException catch (e) {
      Logger.debug('🚨 [STUDY_API] RateLimitException caught: $e');
      rethrow;
    } on InsufficientTokensException catch (e) {
      Logger.debug('🚨 [STUDY_API] InsufficientTokensException caught: $e');
      rethrow;
    } on TokenValidationException {
      // Convert to AuthenticationException for consistency
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } on FunctionException catch (e) {
      Logger.debug(
          '🚨 [STUDY_API] FunctionException caught: status=${e.status}, details=${e.details}');

      // Handle 429 specifically
      if (e.status == 429) {
        final details = e.details as Map<String, dynamic>?;
        final error = details?['error'] as Map<String, dynamic>?;

        if (error?['code'] == 'INSUFFICIENT_TOKENS') {
          // Parse token details if available
          final errorDetails = error?['details'] as Map<String, dynamic>?;
          final required = errorDetails?['required'] as int? ?? 0;
          final available = errorDetails?['available'] as int? ?? 0;

          // If backend doesn't provide proper required tokens, use default fallback
          // (Backend should always provide this value; this is just a safety fallback)
          final actualRequiredTokens = required > 0 ? required : 10;

          throw InsufficientTokensException(
            message: error?['message'] as String? ?? 'Insufficient tokens',
            code: 'INSUFFICIENT_TOKENS',
            requiredTokens: actualRequiredTokens,
            availableTokens: available,
            nextResetTime: errorDetails?['next_reset'] != null
                ? DateTime.tryParse(errorDetails!['next_reset'] as String)
                : null,
          );
        } else {
          // Legacy rate limiting
          throw const RateLimitException(
            message:
                'You have reached your study generation limit. Please try again later.',
            code: 'RATE_LIMITED',
          );
        }
      }

      // Handle other HTTP errors from FunctionException
      if (e.status >= 500) {
        throw const ServerException(
          message: 'Server error occurred. Please try again later.',
          code: 'SERVER_ERROR',
        );
      } else if (e.status == 401) {
        throw const AuthenticationException(
          message: 'Authentication required. Please sign in to continue.',
          code: 'UNAUTHORIZED',
        );
      } else {
        throw ServerException(
          message: 'Request failed: ${e.reasonPhrase}',
          code: 'REQUEST_FAILED',
        );
      }
    } catch (e) {
      Logger.error(
          '🚨 [STUDY_API] Generic exception caught: $e (${e.runtimeType})');
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
  /// Now also includes token consumption information.
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

    // Extract token consumption information
    TokenConsumption? tokenConsumption;
    final bool fromCache = responseData['from_cache'] as bool? ?? false;

    if (!fromCache && data['tokens'] != null) {
      try {
        tokenConsumption =
            TokenConsumption.fromJson(data['tokens'] as Map<String, dynamic>);
        Logger.warning(
            '🪙 [STUDY_API] Token consumption parsed: ${tokenConsumption.consumed} tokens');
      } catch (e) {
        Logger.debug('⚠️ [STUDY_API] Failed to parse token consumption: $e');
      }
    }

    if (fromCache) {
      Logger.debug(
          '🪙 [STUDY_API] Study guide returned from cache - no tokens consumed');
    }

    return StudyGuide(
      id: studyGuide['id'] as String? ?? _uuid.v4(),
      input: input, // Always use the original user input
      inputType: inputType, // Always use the original input type
      summary: content['summary'] as String? ?? 'No summary available',
      interpretation:
          content['interpretation'] as String? ?? 'No interpretation available',
      context: content['context'] as String? ?? 'No context available',
      passage: content['passage']
          as String?, // Optional: LLM-generated Scripture passage for Standard mode
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
      interpretationInsights:
          (content['interpretationInsights'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(), // Optional: for Reflect Mode multi-select
      summaryInsights: (content['summaryInsights'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(), // Optional: for Reflect Mode summary card
      reflectionAnswers: (content['reflectionAnswers'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(), // Optional: for Reflect Mode reflection card
      contextQuestion: content['contextQuestion']
          as String?, // Optional: for Reflect Mode context card
      summaryQuestion: content['summaryQuestion']
          as String?, // Optional: for Reflect Mode summary card
      relatedVersesQuestion: content['relatedVersesQuestion']
          as String?, // Optional: for Reflect Mode verses card
      reflectionQuestion: content['reflectionQuestion']
          as String?, // Optional: for Reflect Mode reflection card
      prayerQuestion: content['prayerQuestion']
          as String?, // Optional: for Reflect Mode prayer card
      tokenConsumption: tokenConsumption, // Token information
      fromCache: fromCache, // Cache status
    );
  }
}
