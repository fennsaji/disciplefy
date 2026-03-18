// frontend/lib/features/walkthrough/data/walkthrough_repository_impl.dart

import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/logger.dart';
import '../domain/walkthrough_repository.dart';
import '../domain/walkthrough_screen.dart';

class WalkthroughRepositoryImpl implements WalkthroughRepository {
  static const _boxName = 'walkthrough';
  final SupabaseClient _supabase;

  WalkthroughRepositoryImpl({required SupabaseClient supabase})
      : _supabase = supabase;

  Future<Box>? _boxFuture;
  Future<Box> get _box => _boxFuture ??= Hive.openBox(_boxName);

  // ── Anonymous user detection ─────────────────────────────────────────────

  bool get _isAnonymous {
    final user = _supabase.auth.currentUser;
    if (user == null) return true;
    // Supabase anonymous users have provider 'anonymous' in appMetadata
    final providers = user.appMetadata['providers'];
    if (providers is List && providers.contains('anonymous')) return true;
    return user.email == null &&
        user.phone == null &&
        user.appMetadata['provider'] == 'anonymous';
  }

  String? get _userId => _supabase.auth.currentUser?.id;

  // ── hasSeen ──────────────────────────────────────────────────────────────

  @override
  Future<bool> hasSeen(WalkthroughScreen screen) async {
    final box = await _box;
    return box.get(screen.key, defaultValue: false) as bool;
  }

  // ── markSeen ─────────────────────────────────────────────────────────────

  @override
  Future<void> markSeen(WalkthroughScreen screen) async {
    // 1. Write to Hive immediately (optimistic)
    final box = await _box;
    await box.put(screen.key, true);

    // 2. Fire-and-forget Supabase write (skip for anonymous users)
    if (_isAnonymous || _userId == null) return;
    _upsertToRemote(screen); // intentionally not awaited
  }

  void _upsertToRemote(WalkthroughScreen screen) {
    _supabase.rpc('append_walkthrough_seen', params: {
      'p_user_id': _userId,
      'p_screen': screen.key,
    }).then((_) {
      // success — no action needed
    }).catchError((e) {
      // Failure is acceptable — union merge on next syncFromRemote will reconcile
      Logger.debug(
          '[Walkthrough] Failed to persist ${screen.key} to remote: $e');
    });
  }

  // ── resetAll ─────────────────────────────────────────────────────────────

  @override
  Future<void> resetAll() async {
    // 1. Clear Hive synchronously
    final box = await _box;
    await box.clear();

    // 2. Clear remote (awaited — caller shows snackbar only on completion)
    if (_isAnonymous || _userId == null) return;
    await _supabase
        .from('user_profiles')
        .update({'walkthrough_seen': []}).eq('id', _userId!);
    // Throws on error — caller catches and shows error snackbar
  }

  // ── syncFromRemote ────────────────────────────────────────────────────────

  @override
  Future<void> syncFromRemote() async {
    if (_isAnonymous || _userId == null) return; // no-op for anonymous

    try {
      final data = await _supabase
          .from('user_profiles')
          .select('walkthrough_seen')
          .eq('id', _userId!)
          .maybeSingle();

      if (data == null) return;

      final remoteList = (data['walkthrough_seen'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      if (remoteList.isEmpty) return;

      // Union merge: mark seen anything that remote says is seen
      final box = await _box;
      for (final key in remoteList) {
        await box.put(key, true);
      }
    } catch (e) {
      // Fall back silently to Hive cache — do not block app startup
      Logger.debug(
          '[Walkthrough] syncFromRemote failed, using local cache: $e');
    }
  }

  // ── migrateToRemote ───────────────────────────────────────────────────────

  /// Called after an anonymous user converts to a full authenticated account.
  /// Reads all Hive-persisted seen flags and writes them to Supabase.
  @override
  Future<void> migrateToRemote() async {
    if (_isAnonymous || _userId == null) return;

    final box = await _box;
    for (final key in box.keys) {
      if (box.get(key) == true) {
        // Skip unknown keys (e.g. from old enum values) rather than risk wrong data
        final match = WalkthroughScreen.values
            .where(
              (s) => s.key == key.toString(),
            )
            .firstOrNull;
        if (match != null) {
          _upsertToRemote(match);
        }
      }
    }
  }
}
