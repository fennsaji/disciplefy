import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usage_stats_model.dart';
import '../../../../core/utils/logger.dart';

/// Remote data source for fetching usage statistics
abstract class UsageStatsRemoteDataSource {
  /// Get current usage statistics for authenticated user
  Future<UsageStatsModel> getUserUsageStats();
}

class UsageStatsRemoteDataSourceImpl implements UsageStatsRemoteDataSource {
  final SupabaseClient supabaseClient;

  UsageStatsRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<UsageStatsModel> getUserUsageStats() async {
    try {
      Logger.info(
        'Fetching user usage stats',
        tag: 'USAGE_STATS_DATASOURCE',
      );

      // Call the get-user-usage-stats edge function
      final response = await supabaseClient.functions.invoke(
        'get-user-usage-stats',
        method: HttpMethod.get,
      );

      // Check for errors
      if (response.status != 200) {
        Logger.error(
          'Failed to fetch usage stats',
          tag: 'USAGE_STATS_DATASOURCE',
          context: {
            'status': response.status,
            'data': response.data,
          },
        );
        throw Exception('Failed to fetch usage stats: ${response.status}');
      }

      // Parse response
      final responseData = response.data as Map<String, dynamic>;

      if (responseData['success'] != true) {
        Logger.error(
          'Usage stats API returned error',
          tag: 'USAGE_STATS_DATASOURCE',
          context: {'response': responseData},
        );
        throw Exception(
            'Usage stats API error: ${responseData['error'] ?? 'Unknown error'}');
      }

      final data = responseData['data'] as Map<String, dynamic>;
      final model = UsageStatsModel.fromJson(data);

      Logger.info(
        'Usage stats fetched successfully',
        tag: 'USAGE_STATS_DATASOURCE',
        context: {
          'plan': model.currentPlan,
          'usage': '${model.tokensUsed}/${model.tokensTotal}',
          'percentage': model.percentage,
          'streak': model.streakDays,
        },
      );

      return model;
    } catch (e) {
      Logger.error(
        'Error fetching usage stats',
        tag: 'USAGE_STATS_DATASOURCE',
        error: e,
      );
      rethrow;
    }
  }
}
