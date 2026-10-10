/// Server side of the growth goal: `user_growth_goals` for the signed-in
/// user (guests too), written through the `set_my_growth_goal` function.
abstract class GrowthGoalRemote {
  /// The stored goal's server key, or null when the user has none.
  Future<String?> fetchGoal();

  /// Saves [goal] (a server key) for the signed-in user. [source] is where it
  /// was picked: `first_run`, `settings` or `app`.
  Future<void> saveGoal(String goal, String source);
}
