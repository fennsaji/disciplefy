/// Subscription pricing model for database-driven pricing
class SubscriptionPricing {
  final Map<String, ProviderPricing> providers;

  const SubscriptionPricing({
    required this.providers,
  });

  /// Get pricing for a specific provider
  ProviderPricing? getProvider(String provider) => providers[provider];

  /// Get Razorpay pricing (default for web)
  ProviderPricing get razorpay =>
      providers['razorpay'] ?? ProviderPricing.empty();

  /// Get Google Play pricing (default for Android)
  ProviderPricing get googlePlay =>
      providers['google_play'] ?? ProviderPricing.empty();

  /// Get Apple App Store pricing (default for iOS)
  ProviderPricing get appleAppStore =>
      providers['apple_appstore'] ?? ProviderPricing.empty();

  factory SubscriptionPricing.fromJson(Map<String, dynamic> json) {
    final providersMap = <String, ProviderPricing>{};

    json.forEach((provider, pricingData) {
      if (pricingData is Map<String, dynamic>) {
        providersMap[provider] = ProviderPricing.fromJson(pricingData);
      }
    });

    return SubscriptionPricing(providers: providersMap);
  }

  Map<String, dynamic> toJson() {
    return providers.map((provider, pricing) => MapEntry(
          provider,
          pricing.toJson(),
        ));
  }

  /// Empty pricing (fallback)
  factory SubscriptionPricing.empty() {
    return SubscriptionPricing(
      providers: {
        'razorpay': ProviderPricing.empty(),
        'google_play': ProviderPricing.empty(),
        'apple_appstore': ProviderPricing.empty(),
      },
    );
  }
}

/// Pricing for a specific payment provider
class ProviderPricing {
  final Map<String, PlanPrice> plans;

  const ProviderPricing({
    required this.plans,
  });

  /// Get price for a specific plan
  PlanPrice? getPlan(String planCode) => plans[planCode];

  /// Get Standard plan price
  PlanPrice get standard => plans['standard'] ?? PlanPrice.fallback('standard');

  /// Get Plus plan price
  PlanPrice get plus => plans['plus'] ?? PlanPrice.fallback('plus');

  /// Get Premium plan price
  PlanPrice get premium => plans['premium'] ?? PlanPrice.fallback('premium');

  factory ProviderPricing.fromJson(Map<String, dynamic> json) {
    final plansMap = <String, PlanPrice>{};

    json.forEach((planCode, priceData) {
      if (priceData is Map<String, dynamic>) {
        plansMap[planCode] = PlanPrice.fromJson(priceData);
      }
    });

    return ProviderPricing(plans: plansMap);
  }

  Map<String, dynamic> toJson() {
    return plans.map((planCode, price) => MapEntry(
          planCode,
          price.toJson(),
        ));
  }

  /// Empty pricing (fallback)
  factory ProviderPricing.empty() {
    return ProviderPricing(
      plans: {
        'standard': PlanPrice.fallback('standard'),
        'plus': PlanPrice.fallback('plus'),
        'premium': PlanPrice.fallback('premium'),
      },
    );
  }
}

/// Individual plan price details
class PlanPrice {
  final int amount; // Amount in minor units (paise/cents)
  final String currency;
  final String formatted; // Formatted display string (e.g., "₹79")
  final String? productId; // IAP product ID (for Google Play / Apple App Store)

  const PlanPrice({
    required this.amount,
    required this.currency,
    required this.formatted,
    this.productId,
  });

  factory PlanPrice.fromJson(Map<String, dynamic> json) {
    return PlanPrice(
      amount: json['amount'] as int,
      currency: json['currency'] as String,
      formatted: json['formatted'] as String,
      productId: json['product_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'currency': currency,
      'formatted': formatted,
      if (productId != null) 'product_id': productId,
    };
  }

  /// Fallback pricing (hardcoded defaults - should rarely be used)
  factory PlanPrice.fallback(String planCode) {
    switch (planCode) {
      case 'standard':
        return const PlanPrice(
          amount: 7900,
          currency: 'INR',
          formatted: '₹79',
        );
      case 'plus':
        return const PlanPrice(
          amount: 14900,
          currency: 'INR',
          formatted: '₹149',
        );
      case 'premium':
        return const PlanPrice(
          amount: 49900,
          currency: 'INR',
          formatted: '₹499',
        );
      default:
        return const PlanPrice(
          amount: 7900,
          currency: 'INR',
          formatted: '₹79',
        );
    }
  }
}
