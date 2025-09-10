import 'package:equatable/equatable.dart';
import '../../domain/entities/token_status.dart';
import '../../../../core/error/failures.dart';

/// Token BLoC States
///
/// Represents all possible states in the token management system
abstract class TokenState extends Equatable {
  const TokenState();

  @override
  List<Object?> get props => [];
}

/// Initial state when the token BLoC is first created
///
/// No token data has been loaded yet
class TokenInitial extends TokenState {
  const TokenInitial();
}

/// State when token data is being loaded from the API
///
/// Shows loading indicators to the user
class TokenLoading extends TokenState {
  final String? operation; // 'fetching', 'purchasing', 'refreshing'

  const TokenLoading({this.operation});

  @override
  List<Object?> get props => [operation];
}

/// State when token data has been successfully loaded
///
/// Contains the complete token status for the user
class TokenLoaded extends TokenState {
  final TokenStatus tokenStatus;
  final DateTime lastUpdated;
  final bool isRefreshing; // True when refreshing in background

  const TokenLoaded({
    required this.tokenStatus,
    required this.lastUpdated,
    this.isRefreshing = false,
  });

  @override
  List<Object?> get props => [tokenStatus, lastUpdated, isRefreshing];

  /// Create a copy with updated fields
  TokenLoaded copyWith({
    TokenStatus? tokenStatus,
    DateTime? lastUpdated,
    bool? isRefreshing,
  }) {
    return TokenLoaded(
      tokenStatus: tokenStatus ?? this.tokenStatus,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  /// Check if token data is stale and needs refreshing
  bool get isStale {
    final now = DateTime.now();
    final staleDuration =
        Duration(minutes: 5); // Consider stale after 5 minutes
    return now.difference(lastUpdated) > staleDuration;
  }

  /// Get user-friendly status message
  String get statusMessage {
    if (tokenStatus.isPremium) {
      return 'Unlimited tokens available';
    } else if (tokenStatus.totalTokens <= 0) {
      return 'No tokens remaining';
    } else if (tokenStatus.totalTokens <= (tokenStatus.dailyLimit * 0.2)) {
      return 'Running low on tokens';
    } else {
      return '${tokenStatus.totalTokens} tokens available';
    }
  }
}

/// State when an error occurs in token operations
///
/// Contains error information and maintains previous token data if available
class TokenError extends TokenState {
  final Failure failure;
  final String? operation; // Which operation failed
  final TokenStatus? previousTokenStatus; // Keep previous data if available

  const TokenError({
    required this.failure,
    this.operation,
    this.previousTokenStatus,
  });

  @override
  List<Object?> get props => [failure, operation, previousTokenStatus];

  /// Get user-friendly error message
  String get errorMessage {
    switch (failure.runtimeType) {
      case NetworkFailure:
        return 'Network error. Please check your connection and try again.';
      case ServerFailure:
        return 'Server error occurred. Please try again later.';
      case InsufficientTokensFailure:
        final insufficientFailure = failure as InsufficientTokensFailure;
        return 'Insufficient tokens. Need ${insufficientFailure.requiredTokens} but only have ${insufficientFailure.availableTokens}.';
      case TokenPaymentFailure:
        return 'Payment failed. Please try again or contact support.';
      case AuthenticationFailure:
        return 'Authentication error. Please log in and try again.';
      default:
        return failure.message;
    }
  }

  /// Check if error is recoverable by retrying
  bool get isRecoverable {
    return failure is NetworkFailure || failure is ServerFailure;
  }
}

/// State when tokens are being consumed by an operation
///
/// Provides immediate feedback while API calls complete in background
class TokenConsuming extends TokenState {
  final TokenStatus currentTokenStatus;
  final int tokensBeingConsumed;
  final String operationType;

  const TokenConsuming({
    required this.currentTokenStatus,
    required this.tokensBeingConsumed,
    required this.operationType,
  });

  @override
  List<Object?> get props =>
      [currentTokenStatus, tokensBeingConsumed, operationType];

  /// Get projected token count after consumption
  int get projectedTokens {
    return (currentTokenStatus.totalTokens - tokensBeingConsumed)
        .clamp(0, double.infinity)
        .toInt();
  }

  /// Check if consumption would exhaust tokens
  bool get willExhaustTokens {
    return projectedTokens <= 0;
  }
}

/// State when token purchase is in progress
///
/// Tracks payment flow and provides status updates
class TokenPurchasing extends TokenState {
  final TokenStatus currentTokenStatus;
  final int tokensToPurchase;
  final double amount;
  final PurchaseStep step;

  const TokenPurchasing({
    required this.currentTokenStatus,
    required this.tokensToPurchase,
    required this.amount,
    required this.step,
  });

  @override
  List<Object?> get props =>
      [currentTokenStatus, tokensToPurchase, amount, step];

  /// Get user-friendly step message
  String get stepMessage {
    switch (step) {
      case PurchaseStep.initiating:
        return 'Initiating purchase...';
      case PurchaseStep.processingPayment:
        return 'Processing payment...';
      case PurchaseStep.verifyingPayment:
        return 'Verifying payment...';
      case PurchaseStep.updatingBalance:
        return 'Updating token balance...';
    }
  }
}

/// State when token purchase is completed successfully
///
/// Shows success feedback and updated token balance
class TokenPurchaseSuccess extends TokenState {
  final TokenStatus updatedTokenStatus;
  final int tokensPurchased;
  final double amountPaid;
  final String paymentId;

  const TokenPurchaseSuccess({
    required this.updatedTokenStatus,
    required this.tokensPurchased,
    required this.amountPaid,
    required this.paymentId,
  });

  @override
  List<Object?> get props =>
      [updatedTokenStatus, tokensPurchased, amountPaid, paymentId];

  /// Get success message
  String get successMessage {
    return 'Successfully purchased $tokensPurchased tokens for ₹${amountPaid.toStringAsFixed(2)}';
  }
}

/// State when user plan upgrade is in progress
///
/// Tracks upgrade process and payment
class TokenPlanUpgrading extends TokenState {
  final TokenStatus currentTokenStatus;
  final String targetPlan;
  final PurchaseStep step;

  const TokenPlanUpgrading({
    required this.currentTokenStatus,
    required this.targetPlan,
    required this.step,
  });

  @override
  List<Object?> get props => [currentTokenStatus, targetPlan, step];
}

/// State when plan upgrade is completed successfully
///
/// Shows new plan benefits and updated token status
class TokenPlanUpgradeSuccess extends TokenState {
  final TokenStatus updatedTokenStatus;
  final String newPlan;

  const TokenPlanUpgradeSuccess({
    required this.updatedTokenStatus,
    required this.newPlan,
  });

  @override
  List<Object?> get props => [updatedTokenStatus, newPlan];

  /// Get success message
  String get successMessage {
    switch (newPlan) {
      case 'standard':
        return 'Welcome to Standard plan! You now get ${updatedTokenStatus.dailyLimit} daily tokens and can purchase more.';
      case 'premium':
        return 'Welcome to Premium plan! You now have unlimited tokens and access to all features.';
      default:
        return 'Plan upgraded successfully!';
    }
  }
}

/// State when token validation is being performed
///
/// Checks if user has sufficient tokens before allowing operations
class TokenValidating extends TokenState {
  final int requiredTokens;
  final String operationType;

  const TokenValidating({
    required this.requiredTokens,
    required this.operationType,
  });

  @override
  List<Object?> get props => [requiredTokens, operationType];
}

/// State when token validation is completed
///
/// Indicates whether user has sufficient tokens
class TokenValidated extends TokenState {
  final bool hasSufficientTokens;
  final int requiredTokens;
  final int availableTokens;
  final String operationType;

  const TokenValidated({
    required this.hasSufficientTokens,
    required this.requiredTokens,
    required this.availableTokens,
    required this.operationType,
  });

  @override
  List<Object?> get props =>
      [hasSufficientTokens, requiredTokens, availableTokens, operationType];

  /// Get validation message
  String get validationMessage {
    if (hasSufficientTokens) {
      return 'You have sufficient tokens for this operation';
    } else {
      final shortage = requiredTokens - availableTokens;
      return 'You need $shortage more tokens to perform this operation';
    }
  }
}

/// Purchase flow steps for tracking progress
enum PurchaseStep {
  initiating,
  processingPayment,
  verifyingPayment,
  updatingBalance,
}

/// Custom failures for token-specific errors
class InsufficientTokensFailure extends Failure {
  final int requiredTokens;
  final int availableTokens;

  const InsufficientTokensFailure({
    required this.requiredTokens,
    required this.availableTokens,
  }) : super(
          message: 'Insufficient tokens for operation',
          code: 'INSUFFICIENT_TOKENS',
        );

  @override
  List<Object?> get props => [requiredTokens, availableTokens];
}

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
