import 'package:flutter/foundation.dart';

/// Ticks whenever the server may have changed the user's token balance
/// outside the token screens: a study guide generated, a follow-up question
/// answered, a plan changed.
///
/// `TokenBloc` listens and refreshes the balance, so screens that only read
/// its state never keep showing the pre-spend balance.
class TokenBalanceChanges extends ValueNotifier<int> {
  TokenBalanceChanges._() : super(0);

  static final TokenBalanceChanges instance = TokenBalanceChanges._();

  void notifyChanged() => value++;
}
