import 'package:equatable/equatable.dart';

/// State of the first-run goal screen's "Start lesson 1" flow.
abstract class FirstRunState extends Equatable {
  const FirstRunState();

  @override
  List<Object?> get props => [];
}

/// Nothing started yet.
class FirstRunIdle extends FirstRunState {
  const FirstRunIdle();
}

/// Saving the choice, starting a guest and enrolling the path.
class FirstRunStarting extends FirstRunState {
  const FirstRunStarting();
}

/// Lesson 1 is ready: open [location].
class FirstRunReady extends FirstRunState {
  final String location;

  const FirstRunReady(this.location);

  @override
  List<Object?> get props => [location];
}

/// Guest mode is off and nobody is signed in: go to the login screen. The
/// goal is remembered for after sign-in.
class FirstRunNeedsLogin extends FirstRunState {
  const FirstRunNeedsLogin();
}

/// The person skipped the goal: go Home with no goal.
class FirstRunSkipped extends FirstRunState {
  const FirstRunSkipped();
}

/// Lesson 1 could not be started. [messageKey] is a translation key shown
/// inline. When [accountRequired] the person already holds a path as a
/// guest, so trying again would not help: the screen offers Home instead.
class FirstRunFailed extends FirstRunState {
  final String messageKey;
  final bool accountRequired;

  const FirstRunFailed(this.messageKey, {this.accountRequired = false});

  @override
  List<Object?> get props => [messageKey, accountRequired];
}
