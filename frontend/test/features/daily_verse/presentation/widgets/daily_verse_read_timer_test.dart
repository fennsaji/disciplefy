import 'package:disciplefy_bible_study/features/daily_verse/data/repositories/streak_repository_impl.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/widgets/daily_verse_read_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({required VoidCallback onRead, bool tickers = true}) =>
      MaterialApp(
        home: TickerMode(
          enabled: tickers,
          child: DailyVerseReadTimer(
            onRead: onRead,
            child: const Text('verse'),
          ),
        ),
      );

  testWidgets('counts as read after five seconds on screen', (tester) async {
    var reads = 0;
    await tester.pumpWidget(host(onRead: () => reads++));

    await tester.pump(const Duration(seconds: 4));
    expect(reads, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(reads, 1);

    // Fires once, not every five seconds.
    await tester.pump(const Duration(seconds: 10));
    expect(reads, 1);
  });

  testWidgets('a hidden tab (tickers off) does not count', (tester) async {
    var reads = 0;
    await tester.pumpWidget(host(onRead: () => reads++, tickers: false));
    await tester.pump(const Duration(seconds: 10));
    expect(reads, 0);

    // Becoming visible starts the full five seconds.
    await tester.pumpWidget(host(onRead: () => reads++));
    await tester.pump(const Duration(seconds: 4));
    expect(reads, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(reads, 1);
  });

  testWidgets('leaving before five seconds does not count', (tester) async {
    var reads = 0;
    await tester.pumpWidget(host(onRead: () => reads++));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(seconds: 5));
    expect(reads, 0);
  });

  testWidgets('a page pushed on top pauses the timer', (tester) async {
    var reads = 0;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      home: DailyVerseReadTimer(
        onRead: () => reads++,
        child: const Text('verse'),
      ),
    ));
    await tester.pump(const Duration(seconds: 2));
    navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('other page')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    expect(reads, 0);
  });

  testWidgets('a backgrounded app does not count, and resuming restarts',
      (tester) async {
    var reads = 0;
    await tester.pumpWidget(host(onRead: () => reads++));
    await tester.pump(const Duration(seconds: 3));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(reads, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 4));
    expect(reads, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(reads, 1);
  });

  testWidgets('left open past midnight, the new day counts again',
      (tester) async {
    var reads = 0;
    var now = DateTime(2026, 10, 6, 23, 59);
    await tester.pumpWidget(MaterialApp(
      home: DailyVerseReadTimer(
        onRead: () => reads++,
        now: () => now,
        child: const Text('verse'),
      ),
    ));
    await tester.pump(const Duration(seconds: 5));
    expect(reads, 1);

    // Still the same day: nothing more.
    await tester.pump(const Duration(seconds: 30));
    expect(reads, 1);

    // Midnight passes while the verse stays on screen.
    now = DateTime(2026, 10, 7, 0, 0, 2);
    await tester.pump(const Duration(seconds: 31));
    expect(reads, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(reads, 2);
  });

  testWidgets('a new day noticed on resume counts again', (tester) async {
    var reads = 0;
    var now = DateTime(2026, 10, 6, 22);
    await tester.pumpWidget(MaterialApp(
      home: DailyVerseReadTimer(
        onRead: () => reads++,
        now: () => now,
        child: const Text('verse'),
      ),
    ));
    await tester.pump(const Duration(seconds: 5));
    expect(reads, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 10, 7, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 5));
    expect(reads, 2);
  });

  test('the streak day is the local date in ASCII yyyy-MM-dd', () {
    expect(streakLocalDate(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
    expect(streakLocalDate(DateTime(2026, 10, 6)), '2026-10-06');
  });
}
