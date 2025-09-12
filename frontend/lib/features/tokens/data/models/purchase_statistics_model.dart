import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/purchase_statistics.dart';

part 'purchase_statistics_model.g.dart';

/// Helper function for tolerant DateTime parsing from JSON
DateTime? parseNullableDateTime(dynamic value) {
  if (value == null) return null;

  if (value is DateTime) return value;

  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  if (value is int) {
    try {
      // Try milliseconds first, then seconds
      var dt = DateTime.fromMillisecondsSinceEpoch(value);
      // If the date is before 1980, assume it's in seconds
      if (dt.year < 1980) {
        dt = DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
      return dt;
    } catch (_) {
      return null;
    }
  }

  return null;
}

/// Helper function for tolerant double parsing from JSON
double? parseNullableDouble(dynamic value) {
  if (value == null) return null;

  if (value is double) return value;
  if (value is int) return value.toDouble();

  if (value is String) {
    try {
      return double.parse(value);
    } catch (_) {
      return null;
    }
  }

  return null;
}

/// Helper function for tolerant double parsing with default value
double parseDoubleWithDefault(dynamic value, double defaultValue) {
  return parseNullableDouble(value) ?? defaultValue;
}

/// Model for purchase statistics
@JsonSerializable()
class PurchaseStatisticsModel {
  /// Total number of purchases made
  @JsonKey(name: 'total_purchases', defaultValue: 0)
  final int totalPurchases;

  /// Total amount spent
  @JsonKey(name: 'total_amount_spent', fromJson: _parseAmountSpent)
  final double totalAmountSpent;

  /// Total tokens purchased
  @JsonKey(name: 'total_tokens_purchased', defaultValue: 0)
  final int totalTokensPurchased;

  /// Average purchase amount
  @JsonKey(name: 'average_purchase_amount', fromJson: _parseAverageAmount)
  final double averagePurchaseAmount;

  /// Date of first purchase
  @JsonKey(name: 'first_purchase_date', fromJson: parseNullableDateTime)
  final DateTime? firstPurchaseDate;

  /// Date of last purchase
  @JsonKey(name: 'last_purchase_date', fromJson: parseNullableDateTime)
  final DateTime? lastPurchaseDate;

  /// Most used payment method
  @JsonKey(name: 'most_used_payment_method')
  final String? mostUsedPaymentMethod;

  const PurchaseStatisticsModel({
    required this.totalPurchases,
    required this.totalAmountSpent,
    required this.totalTokensPurchased,
    required this.averagePurchaseAmount,
    this.firstPurchaseDate,
    this.lastPurchaseDate,
    this.mostUsedPaymentMethod,
  });

  factory PurchaseStatisticsModel.fromJson(Map<String, dynamic> json) =>
      _$PurchaseStatisticsModelFromJson(json);

  Map<String, dynamic> toJson() => _$PurchaseStatisticsModelToJson(this);

  /// Convert model to entity
  PurchaseStatistics toEntity() {
    return PurchaseStatistics(
      totalPurchases: totalPurchases,
      totalTokens: totalTokensPurchased,
      totalSpent: totalAmountSpent,
      averagePurchaseAmount: averagePurchaseAmount,
      firstPurchaseDate: firstPurchaseDate,
      lastPurchaseDate: lastPurchaseDate,
      mostUsedPaymentMethod: mostUsedPaymentMethod,
    );
  }

  /// Tolerant parser for total amount spent
  static double _parseAmountSpent(dynamic value) {
    return parseDoubleWithDefault(value, 0.0);
  }

  /// Tolerant parser for average purchase amount
  static double _parseAverageAmount(dynamic value) {
    return parseDoubleWithDefault(value, 0.0);
  }

  /// Create a copy with updated values
  PurchaseStatisticsModel copyWith({
    int? totalPurchases,
    double? totalAmountSpent,
    int? totalTokensPurchased,
    double? averagePurchaseAmount,
    DateTime? firstPurchaseDate,
    DateTime? lastPurchaseDate,
    String? mostUsedPaymentMethod,
  }) {
    return PurchaseStatisticsModel(
      totalPurchases: totalPurchases ?? this.totalPurchases,
      totalAmountSpent: totalAmountSpent ?? this.totalAmountSpent,
      totalTokensPurchased: totalTokensPurchased ?? this.totalTokensPurchased,
      averagePurchaseAmount:
          averagePurchaseAmount ?? this.averagePurchaseAmount,
      firstPurchaseDate: firstPurchaseDate ?? this.firstPurchaseDate,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      mostUsedPaymentMethod:
          mostUsedPaymentMethod ?? this.mostUsedPaymentMethod,
    );
  }
}
