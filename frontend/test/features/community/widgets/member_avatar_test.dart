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

    // Decoded at the avatar's pixel size (ResizeImage), never full size.
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isA<ResizeImage>());
    expect((avatar.backgroundImage! as ResizeImage).imageProvider,
        isA<NetworkImage>());
    expect(find.text('FS'), findsNothing);
  });

  testWidgets('a member without one falls back to their initials',
      (tester) async {
    await pump(tester, null);

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isNull);
    expect(find.text('FS'), findsOneWidget);
    expect(avatar.backgroundColor, MemberAvatar.colorFor('Fenn Saji'),
        reason: 'the colour follows the name, so a member looks the same '
            'on every screen');
  });

  testWidgets('an empty url counts as no picture', (tester) async {
    await pump(tester, '');

    expect(find.text('FS'), findsOneWidget);
  });

  test('initials: one word gives one letter, more give two', () {
    expect(MemberAvatar.initialsOf('Fenn'), 'F');
    expect(MemberAvatar.initialsOf('priya thomas george'), 'PT');
    expect(MemberAvatar.initialsOf('   '), '?');
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
