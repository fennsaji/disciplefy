import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/pages/generate_simple_screen.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/pages/generate_study_screen.dart';

/// The Generate tab: the single-input screen when `generate_single_input` is
/// on, otherwise the shipped screen unchanged.
class GenerateTabPage extends StatelessWidget {
  /// Text to start with in the single input.
  final String? prefill;

  const GenerateTabPage({super.key, this.prefill});

  @override
  Widget build(BuildContext context) => sl<RolloutFlags>().generateSingleInput
      ? GenerateSimpleScreen(prefill: prefill)
      : const GenerateStudyScreen();
}
