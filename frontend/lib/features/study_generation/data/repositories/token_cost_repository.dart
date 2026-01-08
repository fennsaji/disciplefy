import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/failures.dart';

/// Repository for fetching token costs from backend
class TokenCostRepository {
  final SupabaseClient _supabaseClient;

  // Cache token costs for 5 minutes
  final Map<String, CachedTokenCost> _costCache = {};
  static const _cacheDuration = Duration(minutes: 5);

  TokenCostRepository({required SupabaseClient supabaseClient})
      : _supabaseClient = supabaseClient;

  /// Get token cost for a specific language and mode
  Future<Either<Failure, int>> getTokenCost(
    String language,
    String mode,
  ) async {
    final cacheKey = '$language:$mode';

    // Check cache first
    if (_costCache.containsKey(cacheKey)) {
      final cached = _costCache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheDuration) {
        return Right(cached.cost);
      }
    }

    // Fetch from backend
    try {
      final response = await _supabaseClient.functions.invoke(
        'study-get-token-costs',
        method: HttpMethod.get,
        queryParameters: {
          'language': language,
          'mode': mode,
        },
      );

      if (response.data != null && response.data['success'] == true) {
        final cost = response.data['data']['tokenCost'] as int;

        // Cache the result
        _costCache[cacheKey] = CachedTokenCost(
          cost: cost,
          timestamp: DateTime.now(),
        );

        return Right(cost);
      } else {
        return Left(ServerFailure(
          message: response.data?['error'] ?? 'Failed to fetch token cost',
        ));
      }
    } catch (e) {
      // No fallback - backend API is single source of truth
      print('❌ [TOKEN_COST] API failed for $language:$mode - Error: $e');
      return Left(ServerFailure(
        message: 'Unable to fetch token cost from backend',
      ));
    }
  }

  /// Clear token cost cache (useful after settings changes)
  void clearCache() {
    _costCache.clear();
  }
}

class CachedTokenCost {
  final int cost;
  final DateTime timestamp;

  CachedTokenCost({required this.cost, required this.timestamp});
}
