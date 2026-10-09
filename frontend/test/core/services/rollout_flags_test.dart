import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';

class _Config extends Mock implements SystemConfigService {}

void main() {
  test('flags read the free plan and default off', () {
    final c = _Config();
    when(() => c.isFeatureEnabled(any(), any())).thenReturn(false);
    when(() => c.isFeatureEnabled('guest_mode', 'free')).thenReturn(true);
    final f = RolloutFlags(c);
    expect(f.guestMode, isTrue);
    expect(f.newFirstRun, isFalse);
    expect(f.homeTodayLayout, isFalse);
    expect(f.generateSingleInput, isFalse);
  });
}
