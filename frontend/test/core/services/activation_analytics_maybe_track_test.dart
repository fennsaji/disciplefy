import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/services/activation_analytics.dart';

import '../../helpers/mock_activation_analytics.dart';

void main() {
  tearDown(() async => sl.reset());

  test('maybeTrack forwards to the registered service', () {
    final analytics = registerMockAnalytics();
    ActivationAnalytics.maybeTrack(NuxEvent.goalSelected, {'goal': 'x'});
    verify(() => analytics.track(NuxEvent.goalSelected, {'goal': 'x'}))
        .called(1);
  });

  test('maybeTrack is a no-op when the service is not registered', () {
    expect(() => ActivationAnalytics.maybeTrack(NuxEvent.firstOpen),
        returnsNormally);
  });

  test('maybeTrack swallows a throwing service', () {
    final analytics = MockActivationAnalytics();
    when(() => analytics.track(any(), any())).thenThrow(StateError('boom'));
    sl.registerSingleton<ActivationAnalytics>(analytics);
    expect(() => ActivationAnalytics.maybeTrack(NuxEvent.nfyTap, {}),
        returnsNormally);
  });

  test('maybeTrack swallows a failing factory', () {
    sl.registerLazySingleton<ActivationAnalytics>(
        () => throw StateError('no box'));
    expect(
        () => ActivationAnalytics.maybeTrack(NuxEvent.nfyTap), returnsNormally);
  });

  test('main sends first_open after DI with the device language', () {
    final source = File('lib/main.dart').readAsStringSync();
    final di = source.indexOf('await initializeDependencies();');
    final call = source.indexOf('_trackFirstOpen();');
    expect(di, isNonNegative);
    expect(call, greaterThan(di));
    expect(source, contains(".trackFirstOpenOnce({'language': language})"));
  });
}
