import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/features/onboarding/domain/growth_goals.dart';

/// Icon of a goal's leading tile (first-run goal screen, Change my goal).
IconData growthGoalIcon(GrowthGoal goal) => switch (goal) {
      GrowthGoal.newToFaith => Icons.eco_outlined,
      GrowthGoal.freshStart => Icons.wb_twilight_rounded,
      GrowthGoal.walkWithGod => Icons.directions_walk_rounded,
      GrowthGoal.hopeHardTimes => Icons.light_mode_outlined,
      GrowthGoal.readGospel => Icons.auto_stories_outlined,
      GrowthGoal.understandGospel => Icons.lightbulb_outline_rounded,
    };
