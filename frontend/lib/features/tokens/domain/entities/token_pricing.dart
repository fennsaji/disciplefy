import 'package:equatable/equatable.dart';

/// Token pricing configuration entity
class TokenPricing extends Equatable {
  /// Exchange rate: number of tokens per rupee (e.g., 4 tokens = ₹1)
  final int tokensPerRupee;

  /// Available token packages with pricing
  final List<TokenPackage> packages;

  /// When this pricing became effective
  final DateTime effectiveFrom;

  /// Region code (e.g., 'IN' for India)
  final String? region;

  const TokenPricing({
    required this.tokensPerRupee,
    required this.packages,
    required this.effectiveFrom,
    this.region,
  });

  @override
  List<Object?> get props => [tokensPerRupee, packages, effectiveFrom, region];
}

/// Individual token package entity
class TokenPackage extends Equatable {
  /// Number of tokens in this package
  final int tokens;

  /// Price in rupees
  final int rupees;

  /// Discount percentage (0-100)
  final int discount;

  /// Whether this package is marked as popular/recommended
  final bool isPopular;

  const TokenPackage({
    required this.tokens,
    required this.rupees,
    required this.discount,
    required this.isPopular,
  });

  /// Calculate price per token in paise
  int get pricePerTokenPaise => (rupees * 100) ~/ tokens;

  /// Calculate original price before discount
  int get originalPrice {
    if (discount == 0) return rupees;
    return (rupees * 100) ~/ (100 - discount);
  }

  /// Calculate savings amount in rupees
  int get savingsRupees => originalPrice - rupees;

  @override
  List<Object?> get props => [tokens, rupees, discount, isPopular];
}
