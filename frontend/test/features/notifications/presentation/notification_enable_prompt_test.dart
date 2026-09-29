import 'package:bloc_test/bloc_test.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/services/notification_service.dart';
import 'package:disciplefy_bible_study/features/notifications/presentation/widgets/notification_enable_prompt.dart';
import 'package:disciplefy_bible_study/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:disciplefy_bible_study/features/notifications/presentation/bloc/notification_event.dart';
import 'package:disciplefy_bible_study/features/notifications/presentation/bloc/notification_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_enable_prompt_test.mocks.dart';

class _MockNotificationBloc
    extends MockBloc<NotificationEvent, NotificationState>
    implements NotificationBloc {}

/// Daily verse notifications are on by default. The "turn on notifications"
/// sheet is for users who turned them off — never for a permission that was
/// simply not answered yet (the system asks for that itself).
@GenerateMocks([NotificationService])
void main() {
  late MockNotificationService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = MockNotificationService();
    if (sl.isRegistered<NotificationService>()) {
      sl.unregister<NotificationService>();
    }
    sl.registerLazySingleton<NotificationService>(() => service);
  });

  tearDown(() => sl.reset());

  Future<void> prompt(WidgetTester tester) async {
    final bloc = _MockNotificationBloc();
    whenListen<NotificationState>(bloc, const Stream<NotificationState>.empty(),
        initialState: const NotificationInitial());
    await tester.pumpWidget(BlocProvider<NotificationBloc>.value(
      value: bloc,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showNotificationEnablePrompt(
              context: context,
              type: NotificationPromptType.dailyVerse,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('permission not answered yet: no sheet', (tester) async {
    when(service.areNotificationsEnabled()).thenAnswer((_) async => false);
    when(service.isNotificationPermissionDenied())
        .thenAnswer((_) async => false);

    await prompt(tester);

    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('permission refused by the user: sheet asks again',
      (tester) async {
    when(service.areNotificationsEnabled()).thenAnswer((_) async => false);
    when(service.isNotificationPermissionDenied())
        .thenAnswer((_) async => true);

    await prompt(tester);

    expect(find.byType(BottomSheet), findsOneWidget);
  });
}
