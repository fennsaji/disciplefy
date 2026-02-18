/// Models for Subscription V2 APIs (multi-provider support)
library;

/// Plan pricing information for a specific provider
class PlanPricingModel {
  final String provider;
  final String providerPlanId;
  final int basePriceMinor;
  final String currency;
  final double basePriceFormatted;
  final int? discountedPriceMinor;
  final double? discountedPriceFormatted;
  final int? discountPercentage;

  const PlanPricingModel({
    required this.provider,
    required this.providerPlanId,
    required this.basePriceMinor,
    required this.currency,
    required this.basePriceFormatted,
    this.discountedPriceMinor,
    this.discountedPriceFormatted,
    this.discountPercentage,
  });

  factory PlanPricingModel.fromJson(Map<String, dynamic> json) {
    return PlanPricingModel(
      provider: json['provider'] as String,
      providerPlanId: json['provider_plan_id'] as String,
      basePriceMinor: json['base_price_minor'] as int,
      currency: json['currency'] as String,
      basePriceFormatted: (json['base_price_formatted'] as num).toDouble(),
      discountedPriceMinor: json['discounted_price_minor'] as int?,
      discountedPriceFormatted: json['discounted_price_formatted'] != null
          ? (json['discounted_price_formatted'] as num).toDouble()
          : null,
      discountPercentage: json['discount_percentage'] as int?,
    );
  }
}

/// Subscription plan model
class SubscriptionPlanModel {
  final String planId;
  final String planCode;
  final String planName;
  final int tier;
  final String interval;
  final Map<String, dynamic> features;

  /// Human-readable feature bullets from DB (marketer-written copy).
  /// When non-empty, used directly in UI instead of computed feature strings.
  final List<String> marketingFeatures;
  final String? description;
  final int sortOrder;
  final PlanPricingModel pricing;

  const SubscriptionPlanModel({
    required this.planId,
    required this.planCode,
    required this.planName,
    required this.tier,
    required this.interval,
    required this.features,
    this.marketingFeatures = const [],
    this.description,
    required this.sortOrder,
    required this.pricing,
  });

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    final rawMarketing = json['marketing_features'];
    final marketingFeatures = rawMarketing is List
        ? rawMarketing.whereType<String>().toList()
        : <String>[];

    return SubscriptionPlanModel(
      planId: json['plan_id'] as String,
      planCode: json['plan_code'] as String,
      planName: json['plan_name'] as String,
      tier: json['tier'] as int,
      interval: json['interval'] as String,
      features: json['features'] as Map<String, dynamic>,
      marketingFeatures: marketingFeatures,
      description: json['description'] as String?,
      sortOrder: json['sort_order'] as int,
      pricing:
          PlanPricingModel.fromJson(json['pricing'] as Map<String, dynamic>),
    );
  }

  /// Check if plan has a discount applied
  bool get hasDiscount => pricing.discountedPriceMinor != null;

  /// Get display price (discounted or base)
  double get displayPrice =>
      pricing.discountedPriceFormatted ?? pricing.basePriceFormatted;

  /// Get display price in minor units
  int get displayPriceMinor =>
      pricing.discountedPriceMinor ?? pricing.basePriceMinor;
}

/// Promotional campaign details
class PromotionalCampaignModel {
  final String code;
  final String name;
  final String? description;
  final String discountType;
  final int discountValue;

  const PromotionalCampaignModel({
    required this.code,
    required this.name,
    this.description,
    required this.discountType,
    required this.discountValue,
  });

  factory PromotionalCampaignModel.fromJson(Map<String, dynamic> json) {
    return PromotionalCampaignModel(
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      discountType: json['discount_type'] as String,
      discountValue: json['discount_value'] as int,
    );
  }

  /// Get discount display text
  String get discountDisplayText {
    if (discountType == 'percentage') {
      return '$discountValue% OFF';
    } else {
      return '₹$discountValue OFF';
    }
  }
}

/// Response from get-plans API
class GetPlansResponseModel {
  final bool success;
  final List<SubscriptionPlanModel> plans;
  final PromotionalCampaignModel? promotionalCampaign;

  const GetPlansResponseModel({
    required this.success,
    required this.plans,
    this.promotionalCampaign,
  });

  factory GetPlansResponseModel.fromJson(Map<String, dynamic> json) {
    return GetPlansResponseModel(
      success: json['success'] as bool,
      plans: (json['plans'] as List)
          .map((plan) =>
              SubscriptionPlanModel.fromJson(plan as Map<String, dynamic>))
          .toList(),
      promotionalCampaign: json['promotional_campaign'] != null
          ? PromotionalCampaignModel.fromJson(
              json['promotional_campaign'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Check if any plan has a discount
  bool get hasDiscounts => promotionalCampaign != null;
}

/// Promotional campaign details for validation response
class PromoCampaignDetailsModel {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String discountType;
  final int discountValue;

  const PromoCampaignDetailsModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.discountType,
    required this.discountValue,
  });

  factory PromoCampaignDetailsModel.fromJson(Map<String, dynamic> json) {
    return PromoCampaignDetailsModel(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      discountType: json['discount_type'] as String,
      discountValue: json['discount_value'] as int,
    );
  }

  /// Convert to PromotionalCampaignModel
  PromotionalCampaignModel toPromotionalCampaignModel() {
    return PromotionalCampaignModel(
      code: code,
      name: name,
      description: description,
      discountType: discountType,
      discountValue: discountValue,
    );
  }
}

/// Response from validate-promo-code API
class ValidatePromoCodeResponseModel {
  final bool valid;
  final PromoCampaignDetailsModel? campaign;
  final String message;

  const ValidatePromoCodeResponseModel({
    required this.valid,
    this.campaign,
    required this.message,
  });

  factory ValidatePromoCodeResponseModel.fromJson(Map<String, dynamic> json) {
    return ValidatePromoCodeResponseModel(
      valid: json['valid'] as bool,
      campaign: json['campaign'] != null
          ? PromoCampaignDetailsModel.fromJson(
              json['campaign'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String,
    );
  }
}

/// Response from create-subscription-v2 API
class CreateSubscriptionV2ResponseModel {
  final bool success;
  final String subscriptionId;
  final String providerSubscriptionId;
  final String? authorizationUrl; // For Razorpay only
  final String status;

  const CreateSubscriptionV2ResponseModel({
    required this.success,
    required this.subscriptionId,
    required this.providerSubscriptionId,
    this.authorizationUrl,
    required this.status,
  });

  factory CreateSubscriptionV2ResponseModel.fromJson(
      Map<String, dynamic> json) {
    return CreateSubscriptionV2ResponseModel(
      success: json['success'] as bool,
      subscriptionId: json['subscription_id'] as String,
      providerSubscriptionId: json['provider_subscription_id'] as String,
      authorizationUrl: json['authorization_url'] as String?,
      status: json['status'] as String,
    );
  }

  /// Check if this is a Razorpay subscription requiring authorization
  bool get requiresAuthorization => authorizationUrl != null;

  /// Check if subscription is immediately active (IAP)
  bool get isImmediatelyActive => status == 'active';
}
