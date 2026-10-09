import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/voice_buddy/data/models/voice_preferences_model.dart';

void main() {
  test('parses a real allowance', () {
    final quota = VoiceQuotaModel.fromJson({
      'can_start': true,
      'quota_limit': 3,
      'quota_used': 1,
      'quota_remaining': 2,
      'tier': 'standard',
    });
    expect(quota.quotaLimit, 3);
    expect(quota.quotaRemaining, 2);
  });

  test('an error payload is not an allowance (no "0 of 0")', () {
    // check_voice_quota once answered an unauthenticated call with this
    // shape; read as data it showed "0 of 0 left this month".
    expect(
      () => VoiceQuotaModel.fromJson({
        'error': 'User not authenticated',
        'can_start': false,
        'quota_limit': 0,
        'quota_used': 0,
        'quota_remaining': 0,
        'tier': 'free',
      }),
      throwsFormatException,
    );
  });
}
