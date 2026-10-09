import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/services/activation_analytics.dart';

class MockActivationAnalytics extends Mock implements ActivationAnalytics {}

/// Registers a [MockActivationAnalytics] in [sl] whose `track` completes.
/// Unregister with `sl.reset()` or `sl.unregister<ActivationAnalytics>()`.
MockActivationAnalytics registerMockAnalytics() {
  registerFallbackValue(NuxEvent.firstOpen);
  final analytics = MockActivationAnalytics();
  when(() => analytics.track(any(), any())).thenAnswer((_) async {});
  if (sl.isRegistered<ActivationAnalytics>()) {
    sl.unregister<ActivationAnalytics>();
  }
  sl.registerSingleton<ActivationAnalytics>(analytics);
  return analytics;
}
