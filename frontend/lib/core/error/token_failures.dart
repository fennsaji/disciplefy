import 'failures.dart';

/// Custom failures for token-specific errors

/// Failure when user has insufficient tokens for an operation
class InsufficientTokensFailure extends Failure {
  final int requiredTokens;
  final int availableTokens;
  final DateTime? nextResetTime;

  const InsufficientTokensFailure({
    required this.requiredTokens,
    required this.availableTokens,
    this.nextResetTime,
  }) : super(
          message: 'Insufficient tokens for operation',
          code: 'INSUFFICIENT_TOKENS',
        );

  @override
  List<Object?> get props => [requiredTokens, availableTokens, nextResetTime];
}

/// Failure when token payment processing fails
class TokenPaymentFailure extends Failure {
  final String? paymentError;

  const TokenPaymentFailure({
    this.paymentError,
  }) : super(
          message: 'Payment processing failed',
          code: 'PAYMENT_FAILED',
        );

  @override
  List<Object?> get props => [paymentError];
}

/// Failure when plan upgrade operation fails
class PlanUpgradeFailure extends Failure {
  final String? upgradeError;

  const PlanUpgradeFailure({
    this.upgradeError,
  }) : super(
          message: 'Plan upgrade failed',
          code: 'PLAN_UPGRADE_FAILED',
        );

  @override
  List<Object?> get props => [upgradeError];
}
