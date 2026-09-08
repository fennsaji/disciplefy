import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/community/presentation/widgets/member_avatar.dart';

/// The comments sheet drew its own initials-only circle, so a member with a
/// profile picture turned into a letter the moment they commented. One widget
/// now serves posts and comments; these pin the two states it has.
void main() {
  Future<void> pump(WidgetTester tester, String? url) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemberAvatar(
              displayName: 'Fenn Saji',
              accentColor: Colors.indigo,
              avatarUrl: url,
              radius: 16,
            ),
          ),
        ),
      );

  testWidgets('a member with a picture shows it, not their initial',
      (tester) async {
    await pump(tester, 'https://example.com/fenn.jpg');
    // The test binding answers every request with 400, so the decode failure is
    // expected here; the assertion is about which provider was handed over.
    tester.takeException();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isA<NetworkImage>());
    expect(find.text('F'), findsNothing);
  });

  testWidgets('a member without one falls back to their initial',
      (tester) async {
    await pump(tester, null);

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isNull);
    expect(find.text('F'), findsOneWidget);
  });

  testWidgets('an empty url counts as no picture', (tester) async {
    await pump(tester, '');

    expect(find.text('F'), findsOneWidget);
  });

  testWidgets('a nameless member gets a placeholder rather than a crash',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MemberAvatar(displayName: '', accentColor: Colors.indigo),
      ),
    ));

    expect(find.text('?'), findsOneWidget);
  });
}
