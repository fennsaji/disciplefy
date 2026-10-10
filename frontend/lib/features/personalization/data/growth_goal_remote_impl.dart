import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/features/personalization/domain/growth_goal_remote.dart';

/// [GrowthGoalRemote] over Supabase: reads the caller's row (RLS: own row
/// only) and writes through `set_my_growth_goal`.
class GrowthGoalRemoteImpl implements GrowthGoalRemote {
  final SupabaseClient _client;

  GrowthGoalRemoteImpl({required SupabaseClient client}) : _client = client;

  @override
  Future<String?> fetchGoal() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('user_growth_goals')
        .select('goal')
        .eq('user_id', userId)
        .maybeSingle();
    final goal = row?['goal'];
    return goal is String ? goal : null;
  }

  @override
  Future<void> saveGoal(String goal, String source) async {
    await _client.rpc('set_my_growth_goal',
        params: {'p_goal': goal, 'p_source': source});
  }
}
