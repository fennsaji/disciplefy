import 'package:supabase_flutter/supabase_flutter.dart';

/// Fetches a previously saved study guide row by its `study_guides.id`.
///
/// Returns `null` when the row does not exist or the fetch fails — callers
/// should fall back to navigating by input params in that case.
Future<Map<String, dynamic>?> fetchSavedGuide(String id) async {
  try {
    return await Supabase.instance.client
        .from('study_guides')
        .select()
        .eq('id', id)
        .maybeSingle();
  } catch (_) {
    return null;
  }
}
