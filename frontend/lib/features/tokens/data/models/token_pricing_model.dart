import '../../domain/entities/token_pricing.dart';

/// Model for token pricing configuration from backend
class TokenPricingModel extends TokenPricing {
  const TokenPricingModel({
    required super.tokensPerRupee,
    required super.packages,
    required super.effectiveFrom,
    super.region,
  });

  /// Creates TokenPricingModel from JSON response
  factory TokenPricingModel.fromJson(Map<String, dynamic> json) {
    final packagesJson = json['packages'] as List<dynamic>;
    final packages = packagesJson
        .map((pkg) => TokenPackageModel.fromJson(pkg as Map<String, dynamic>))
        .toList();

    return TokenPricingModel(
      tokensPerRupee: json['tokensPerRupee'] as int,
      packages: packages,
      effectiveFrom: DateTime.parse(json['effectiveFrom'] as String),
      region: json['region'] as String?,
    );
  }

  /// Converts TokenPricingModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'tokensPerRupee': tokensPerRupee,
      'packages':
          packages.map((pkg) => (pkg as TokenPackageModel).toJson()).toList(),
      'effectiveFrom': effectiveFrom.toIso8601String(),
      if (region != null) 'region': region,
    };
  }
}

/// Model for individual token package
class TokenPackageModel extends TokenPackage {
  const TokenPackageModel({
    required super.tokens,
    required super.rupees,
    required super.discount,
    required super.isPopular,
  });

  /// Creates TokenPackageModel from JSON response
  factory TokenPackageModel.fromJson(Map<String, dynamic> json) {
    return TokenPackageModel(
      tokens: json['tokens'] as int,
      rupees: json['rupees'] as int,
      discount: json['discount'] as int,
      isPopular: json['isPopular'] as bool,
    );
  }

  /// Converts TokenPackageModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'tokens': tokens,
      'rupees': rupees,
      'discount': discount,
      'isPopular': isPopular,
    };
  }
}
