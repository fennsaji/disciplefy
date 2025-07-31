import 'dart:convert';
import 'dart:io';
import 'package:dartz/dartz.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/services/http_service.dart';
import '../models/daily_verse_model.dart';
import '../../domain/entities/daily_verse_entity.dart';

/// API service for fetching daily Bible verses
class DailyVerseApiService {
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
      String url = '${AppConfig.supabaseUrl}$_dailyVerseEndpoint';
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
    } on SocketException catch (e) {
      return Left(NetworkFailure(
        message: 'Network connection failed: ${e.message}',
      ));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on FormatException catch (e) {
      return Left(ServerFailure(
        message: 'Invalid response format: ${e.message}',
      ));
    } catch (e) {
      return Left(NetworkFailure(
        message: 'Unexpected error occurred: $e',
      ));
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

    } on FormatException catch (e) {
      return Left(ServerFailure(
        message: 'Invalid JSON format in response: ${e.message}',
      ));
    } on TypeError catch (e) {
      return Left(ServerFailure(
        message: 'Data type mismatch in response: ${e.toString()}',
      ));
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
        '${AppConfig.supabaseUrl}$_dailyVerseEndpoint',
        headers: headers,
      );

      return response.statusCode == 200;
    } on SocketException {
      return false;
    } on AuthenticationException {
      return false;
    } on ServerException {
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Dispose HTTP client
  void dispose() {
    _httpService.dispose();
  }
}