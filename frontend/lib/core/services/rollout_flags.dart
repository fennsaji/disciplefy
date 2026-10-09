import 'package:flutter/foundation.dart';

import 'package:disciplefy_bible_study/core/services/system_config_service.dart';

/// Dark-launch switches for the new-user redesign (admin-web → Feature flags).
///
/// Each switch is the flag's `enabled` state alone: plans do not apply (a
/// switch enabled with no plans selected is still on). A missing flag row, or
/// no config yet, reads as off.
///
/// Notifies listeners when a config refetch flips any switch, so screens that
/// branch on one pick up an admin toggle without a restart.
class RolloutFlags extends ChangeNotifier {
  final SystemConfigService _config;
  late List<bool> _last;

  RolloutFlags(this._config) {
    _last = _snapshot();
    _config.addListener(_onConfigChanged);
  }

  static const newFirstRunKey = 'new_first_run';
  static const guestModeKey = 'guest_mode';
  static const homeTodayLayoutKey = 'home_today_layout';
  static const generateSingleInputKey = 'generate_single_input';

  static const _keys = [
    newFirstRunKey,
    guestModeKey,
    homeTodayLayoutKey,
    generateSingleInputKey,
  ];

  bool _on(String key) => _config.config?.featureFlags[key]?.enabled ?? false;
  bool get newFirstRun => _on(newFirstRunKey);
  bool get guestMode => _on(guestModeKey);
  bool get homeTodayLayout => _on(homeTodayLayoutKey);
  bool get generateSingleInput => _on(generateSingleInputKey);

  List<bool> _snapshot() => [for (final k in _keys) _on(k)];

  void _onConfigChanged() {
    final now = _snapshot();
    if (listEquals(now, _last)) return;
    _last = now;
    notifyListeners();
  }

  @override
  void dispose() {
    _config.removeListener(_onConfigChanged);
    super.dispose();
  }
}
