import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/features/home/domain/new_for_you/new_for_you_remote.dart';
import 'package:disciplefy_bible_study/features/home/domain/new_for_you/new_for_you_scheduler.dart';

/// [NewForYouRemote] over the `sync_new_for_you` database function, which
/// merges the state for `auth.uid()` and adds the features already tried.
class NewForYouRemoteImpl implements NewForYouRemote {
  final SupabaseClient _client;

  NewForYouRemoteImpl({required SupabaseClient client}) : _client = client;

  @override
  Future<NewForYouSync> sync(NewForYouState local) async {
    final result = await _client
        .rpc('sync_new_for_you', params: {'p_state': local.toJson()});
    return parseNewForYouSync(result);
  }
}

/// Reads the function's JSON result. Anything unexpected gives an empty
/// state with no start date (so no banner), never an error.
NewForYouSync parseNewForYouSync(Object? result) {
  if (result is! Map) return NewForYouSync(state: NewForYouState.empty());
  final json = Map<String, dynamic>.from(result);
  final started = json['started_at'];
  return NewForYouSync(
    state: NewForYouState.fromJson(json),
    startedAt: started is String ? DateTime.tryParse(started) : null,
  );
}
