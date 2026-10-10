import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/next_paths_card.dart';

/// Home's card when the user has no active path: "Choose your first path",
/// or "What next?" once the server reports the last path as finished.
///
/// The paths come from the server's next-path engine ([NextPathsCard]): the
/// user's growth goal paths first, then featured ones; a guest only gets
/// guest-accessible paths.
class ChooseFirstPathCard extends StatelessWidget {
  /// Called when a path page reports a change (enrolled, lesson done), so
  /// Home can load the new active path.
  final VoidCallback? onPathChanged;

  const ChooseFirstPathCard({super.key, this.onPathChanged});

  @override
  Widget build(BuildContext context) => NextPathsCard(
        mode: NextPathsCardMode.firstPath,
        onPathChanged: onPathChanged,
      );
}
