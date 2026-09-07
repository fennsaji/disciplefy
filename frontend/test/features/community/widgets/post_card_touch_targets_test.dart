import 'package:flutter/material.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_post_card.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/reaction_button.dart';

/// Material's minimum comfortable touch target.
const double kMinTarget = 44;

const _post = FellowshipPostEntity(
  id: 'p',
  fellowshipId: 'f',
  authorUserId: 'a',
  content: 'Is speaking in tongues important?',
  postType: 'question',
  reactionCounts: {},
  isDeleted: false,
  createdAt: 't',
  authorDisplayName: 'Fenn',
  commentCount: 1,
);

Future<void> _pumpCard(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: FellowshipPostCard(
        post: _post,
        fellowshipId: 'f',
        onCommentTap: () {},
        onShareTap: () {},
      ),
    ),
  ));
  // The localization delegates resolve asynchronously; the first frame is a
  // placeholder.
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the comment button is at least 44px tall', (tester) async {
    await _pumpCard(tester);

    final button = find.ancestor(
      of: find.byIcon(Icons.chat_bubble_outline_rounded),
      matching: find.byType(InkWell),
    );
    expect(button, findsWidgets);
    expect(
        tester.getSize(button.first).height, greaterThanOrEqualTo(kMinTarget));
  });

  testWidgets('the reaction button is at least 44px tall', (tester) async {
    await _pumpCard(tester);

    expect(tester.getSize(find.byType(FellowshipReactionButton)).height,
        greaterThanOrEqualTo(kMinTarget));
  });

  testWidgets('the share button is at least 44px in both directions',
      (tester) async {
    await _pumpCard(tester);

    final size = tester.getSize(find.ancestor(
      of: find.byIcon(Icons.share_outlined),
      matching: find.byType(IconButton),
    ));
    expect(size.height, greaterThanOrEqualTo(kMinTarget));
    expect(size.width, greaterThanOrEqualTo(kMinTarget));
  });
}
