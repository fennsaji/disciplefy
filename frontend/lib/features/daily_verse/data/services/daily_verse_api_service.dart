import 'dart:convert';
import 'package:dartz/dartz.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/services/http_service.dart';
import '../models/daily_verse_model.dart';
import '../../domain/entities/daily_verse_entity.dart';

/// API service for fetching daily Bible verses
class DailyVerseApiService {
  static String get _baseUrl => AppConfig.baseApiUrl.replaceAll('/functions/v1', '');
  static const String _dailyVerseEndpoint = '/functions/v1/daily-verse';
  
  final HttpService _httpService;

  DailyVerseApiService({HttpService? httpService}) 
      : _httpService = httpService ?? HttpServiceProvider.instance;

  /// Get today's daily verse
  Future<Either<Failure, DailyVerseEntity>> getTodaysVerse() async => getDailyVerse(null);

  /// Get daily verse for a specific date
  Future<Either<Failure, DailyVerseEntity>> getDailyVerse(DateTime? date) async {
    try {
      final headers = await _httpService.createHeaders();
      
      // Build URL with optional date parameter
      String url = '$_baseUrl$_dailyVerseEndpoint';
      if (date != null) {
        final dateString = date.toIso8601String().split('T')[0]; // YYYY-MM-DD
        url += '?date=$dateString';
      }

      final response = await _httpService.get(url, headers: headers);

      if (response.statusCode == 200) {
        return _parseVerseResponse(response.body);
      } else if (response.statusCode == 404) {
        return const Left(ServerFailure(
          message: 'Daily verse not found for the requested date',
        ));
      } else {
        final Map<String, dynamic>? errorData = 
            json.decode(response.body) as Map<String, dynamic>?;
        
        return Left(ServerFailure(
          message: errorData?['message'] ?? 'Failed to fetch daily verse',
        ));
      }
    } catch (e) {
      if (e is AuthenticationException) {
        return Left(AuthenticationFailure(message: e.message));
      } else if (e is ServerException) {
        return Left(ServerFailure(message: e.message));
      } else {
        return Left(NetworkFailure(
          message: 'Failed to connect to daily verse service: $e',
        ));
      }
    }
  }

  /// Parse daily verse API response
  Either<Failure, DailyVerseEntity> _parseVerseResponse(String responseBody) {
    try {
      final Map<String, dynamic> jsonData = json.decode(responseBody);
      
      if (!jsonData.containsKey('success') || !jsonData.containsKey('data')) {
        return const Left(ServerFailure(
          message: 'Invalid response format from daily verse API',
        ));
      }

      if (jsonData['success'] != true) {
        return Left(ServerFailure(
          message: jsonData['message'] ?? 'Daily verse API returned failure',
        ));
      }

      final DailyVerseResponse verseResponse = DailyVerseResponse.fromJson(jsonData);
      return Right(verseResponse.data.toEntity());

    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to parse daily verse response: $e',
      ));
    }
  }



  /// Check if service is available (health check)
  Future<bool> isServiceAvailable() async {
    try {
      final headers = await _httpService.createHeaders();
      
      final response = await _httpService.get(
        '$_baseUrl$_dailyVerseEndpoint',
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Dispose HTTP client
  void dispose() {
    _httpService.dispose();
  }
}