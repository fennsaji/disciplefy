import 'package:disciplefy_bible_study/core/services/system_config_service.dart';

/// Dark-launch switches for the new-user redesign (admin-web → Feature flags).
/// A missing flag row reads as off.
class RolloutFlags {
  final SystemConfigService _config;
  RolloutFlags(this._config);

  static const newFirstRunKey = 'new_first_run';
  static const guestModeKey = 'guest_mode';
  static const homeTodayLayoutKey = 'home_today_layout';
  static const generateSingleInputKey = 'generate_single_input';

  bool _on(String key) => _config.isFeatureEnabled(key, 'free');
  bool get newFirstRun => _on(newFirstRunKey);
  bool get guestMode => _on(guestModeKey);
  bool get homeTodayLayout => _on(homeTodayLayoutKey);
  bool get generateSingleInput => _on(generateSingleInputKey);
}
