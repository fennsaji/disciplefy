import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_member_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/mention_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<FellowshipMemberEntity> _members(int count) => [
      for (var i = 0; i < count; i++)
        FellowshipMemberEntity(
          userId: 'u$i',
          displayName: 'Member Number $i',
          role: 'member',
          joinedAt: 't',
          isMuted: false,
        ),
    ];

Future<void> _openSheet(WidgetTester tester, {required int memberCount}) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showMentionSheet(
            context,
            disciplerAllowed: true,
            mentors: const [],
            members: _members(memberCount),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a long member list scrolls instead of overflowing',
      (tester) async {
    await _openSheet(tester, memberCount: 40);

    expect(find.byType(ListView), findsOneWidget);
    // An unbounded Column would have overflowed and painted out of bounds.
    expect(tester.takeException(), isNull);
  });

  testWidgets('Discipler stays reachable at the top of a long list',
      (tester) async {
    await _openSheet(tester, memberCount: 40);

    // Clipping used to push this row off the top of the screen entirely.
    expect(find.text('Discipler').hitTestable(), findsOneWidget);
  });

  testWidgets('typing in the search box narrows the list', (tester) async {
    await _openSheet(tester, memberCount: 40);

    await tester.enterText(find.byType(TextField), 'Number 7');
    await tester.pumpAndSettle();

    expect(find.text('Member Number 7'), findsOneWidget);
    expect(find.text('Member Number 1'), findsNothing);
  });

  testWidgets('a query matching nobody says so', (tester) async {
    await _openSheet(tester, memberCount: 5);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsNothing);
    expect(find.textContaining('No one'), findsOneWidget);
  });
}
