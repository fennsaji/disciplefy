import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/services/api_auth_helper.dart';
import '../../domain/entities/reflection_response.dart';
import '../../domain/entities/study_mode.dart';
import '../models/reflection_model.dart';

/// Abstract contract for remote reflection operations.
abstract class ReflectionsRemoteDataSource {
  /// Saves a reflection session to the backend.
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if user is not authenticated.
  Future<ReflectionModel> saveReflection({
    required String studyGuideId,
    required StudyMode studyMode,
    required Map<String, dynamic> responses,
    required int timeSpentSeconds,
    DateTime? completedAt,
  });

  /// Gets a reflection by its ID.
  Future<ReflectionModel?> getReflection(String reflectionId);

  /// Gets a reflection for a specific study guide.
  Future<ReflectionModel?> getReflectionForGuide(String studyGuideId);

  /// Lists user's reflections with pagination.
  Future<ReflectionListModel> listReflections({
    int page = 1,
    int perPage = 20,
    StudyMode? studyMode,
  });

  /// Deletes a reflection by ID.
  Future<void> deleteReflection(String reflectionId);

  /// Gets reflection statistics for the current user.
  Future<ReflectionStatsModel> getReflectionStats();
}

/// Implementation using Supabase Edge Functions.
class ReflectionsRemoteDataSourceImpl implements ReflectionsRemoteDataSource {
  final SupabaseClient _supabaseClient;

  ReflectionsRemoteDataSourceImpl({
    required SupabaseClient supabaseClient,
  }) : _supabaseClient = supabaseClient;

  @override
  Future<ReflectionModel> saveReflection({
    required String studyGuideId,
    required StudyMode studyMode,
    required Map<String, dynamic> responses,
    required int timeSpentSeconds,
    DateTime? completedAt,
  }) async {
    try {
      // Validate authentication
      await ApiAuthHelper.validateTokenForRequest();
      final headers = await ApiAuthHelper.getAuthHeaders();

      final body = {
        'study_guide_id': studyGuideId,
        'study_mode': studyMode.value,
        'responses': responses,
        'time_spent_seconds': timeSpentSeconds,
        if (completedAt != null) 'completed_at': completedAt.toIso8601String(),
      };

      final response = await _supabaseClient.functions.invoke(
        'study-reflections',
        body: body,
        headers: headers,
      );

      if (response.status == 200 || response.status == 201) {
        final data = response.data as Map<String, dynamic>;
        final reflectionData =
            data['data']?['reflection'] as Map<String, dynamic>?;

        if (reflectionData == null) {
          throw ServerException(
            message: 'Invalid response: missing reflection data',
            code: 'INVALID_RESPONSE',
          );
        }

        return ReflectionModel.fromJson(reflectionData);
      } else if (response.status == 401) {
        throw AuthenticationException(
          message: 'Authentication required to save reflections',
          code: 'UNAUTHORIZED',
        );
      } else {
        final errorData = response.data as Map<String, dynamic>?;
        throw ServerException(
          message: errorData?['error']?['message'] as String? ??
              'Failed to save reflection',
          code: errorData?['error']?['code'] as String? ?? 'SERVER_ERROR',
        );
      }
    } on AuthenticationException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw NetworkException(
        message: 'Network error saving reflection: $e',
        code: 'NETWORK_ERROR',
      );
    }
  }

  @override
  Future<ReflectionModel?> getReflection(String reflectionId) async {
    try {
      await ApiAuthHelper.validateTokenForRequest();
      final headers = await ApiAuthHelper.getAuthHeaders();

      final response = await _supabaseClient.functions.invoke(
        'study-reflections?id=$reflectionId',
        headers: headers,
        method: HttpMethod.get,
      );

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        final reflectionData =
            data['data']?['reflection'] as Map<String, dynamic>?;

        if (reflectionData == null) {
          return null;
        }

        return ReflectionModel.fromJson(reflectionData);
      } else if (response.status == 404) {
        return null;
      } else if (response.status == 401) {
        throw AuthenticationException(
          message: 'Authentication required',
          code: 'UNAUTHORIZED',
        );
      } else {
        throw ServerException(
          message: 'Failed to get reflection',
          code: 'SERVER_ERROR',
        );
      }
    } on AuthenticationException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw NetworkException(
        message: 'Network error: $e',
        code: 'NETWORK_ERROR',
      );
    }
  }

  @override
  Future<ReflectionModel?> getReflectionForGuide(String studyGuideId) async {
    try {
      await ApiAuthHelper.validateTokenForRequest();
      final headers = await ApiAuthHelper.getAuthHeaders();

      final response = await _supabaseClient.functions.invoke(
        'study-reflections?study_guide_id=$studyGuideId',
        headers: headers,
        method: HttpMethod.get,
      );

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        final reflectionData =
            data['data']?['reflection'] as Map<String, dynamic>?;

        if (reflectionData == null) {
          return null;
        }

        return ReflectionModel.fromJson(reflectionData);
      } else if (response.status == 401) {
        throw AuthenticationException(
          message: 'Authentication required',
          code: 'UNAUTHORIZED',
        );
      } else {
        throw ServerException(
          message: 'Failed to get reflection',
          code: 'SERVER_ERROR',
        );
      }
    } on AuthenticationException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw NetworkException(
        message: 'Network error: $e',
        code: 'NETWORK_ERROR',
      );
    }
  }

  @override
  Future<ReflectionListModel> listReflections({
    int page = 1,
    int perPage = 20,
    StudyMode? studyMode,
  }) async {
    try {
      await ApiAuthHelper.validateTokenForRequest();
      final headers = await ApiAuthHelper.getAuthHeaders();

      var queryParams = 'page=$page&per_page=$perPage';
      if (studyMode != null) {
        queryParams += '&study_mode=${studyMode.value}';
      }

      final response = await _supabaseClient.functions.invoke(
        'study-reflections?$queryParams',
        headers: headers,
        method: HttpMethod.get,
      );

      if (response.status == 200) {
        return ReflectionListModel.fromJson(
            response.data as Map<String, dynamic>);
      } else if (response.status == 401) {
        throw AuthenticationException(
          message: 'Authentication required',
          code: 'UNAUTHORIZED',
        );
      } else {
        throw ServerException(
          message: 'Failed to list reflections',
          code: 'SERVER_ERROR',
        );
      }
    } on AuthenticationException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw NetworkException(
        message: 'Network error: $e',
        code: 'NETWORK_ERROR',
      );
    }
  }

  @override
  Future<void> deleteReflection(String reflectionId) async {
    try {
      await ApiAuthHelper.validateTokenForRequest();
      final headers = await ApiAuthHelper.getAuthHeaders();

      final response = await _supabaseClient.functions.invoke(
        'study-reflections?id=$reflectionId',
        headers: headers,
        method: HttpMethod.delete,
      );

      if (response.status == 200) {
        return;
      } else if (response.status == 401) {
        throw AuthenticationException(
          message: 'Authentication required',
          code: 'UNAUTHORIZED',
        );
      } else if (response.status == 404) {
        throw ServerException(
          message: 'Reflection not found',
          code: 'NOT_FOUND',
        );
      } else {
        throw ServerException(
          message: 'Failed to delete reflection',
          code: 'SERVER_ERROR',
        );
      }
    } on AuthenticationException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw NetworkException(
        message: 'Network error: $e',
        code: 'NETWORK_ERROR',
      );
    }
  }

  @override
  Future<ReflectionStatsModel> getReflectionStats() async {
    try {
      await ApiAuthHelper.validateTokenForRequest();
      final headers = await ApiAuthHelper.getAuthHeaders();

      final response = await _supabaseClient.functions.invoke(
        'study-reflections?stats=true',
        headers: headers,
        method: HttpMethod.get,
      );

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        final statsData = data['data']?['stats'] as Map<String, dynamic>?;

        if (statsData == null) {
          return const ReflectionStatsModel(
            totalReflections: 0,
            totalTimeSpentSeconds: 0,
            reflectionsByMode: {},
            mostCommonLifeAreas: [],
          );
        }

        return ReflectionStatsModel.fromJson(statsData);
      } else if (response.status == 401) {
        throw AuthenticationException(
          message: 'Authentication required',
          code: 'UNAUTHORIZED',
        );
      } else {
        throw ServerException(
          message: 'Failed to get stats',
          code: 'SERVER_ERROR',
        );
      }
    } on AuthenticationException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw NetworkException(
        message: 'Network error: $e',
        code: 'NETWORK_ERROR',
      );
    }
  }
}
