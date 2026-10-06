import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/repositories/streak_repository.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_event.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_state.dart';

/// Counts a finished lesson toward the one daily streak.
///
/// When the app-wide [DailyVerseBloc] has today's verse loaded, the count
/// goes through it: the server is called once, the new count shows on Home
/// at once (no reload), and a milestone push is sent as for a verse read.
/// Otherwise the streak is touched directly and the next verse load picks
/// up the new count. Never throws: the streak is secondary to the lesson.
Future<void> countLessonTowardStreak(BuildContext context) async {
  DailyVerseBloc? bloc;
  try {
    bloc = context.read<DailyVerseBloc>();
  } on ProviderNotFoundException {
    bloc = null;
  }

  if (bloc != null && bloc.state is DailyVerseLoaded) {
    bloc.add(const MarkVerseAsViewed());
    return;
  }

  try {
    await sl<StreakRepository>().markActivityToday();
  } catch (e) {
    Logger.warning('[STREAK] Could not count the lesson toward the streak: $e');
  }
}
