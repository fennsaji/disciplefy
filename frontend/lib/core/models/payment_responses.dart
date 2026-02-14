// Platform-agnostic payment response models
// These replace razorpay_flutter types to avoid native plugin dependencies on web

class PaymentSuccessResponse {
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final Map<String, dynamic>? data;

  PaymentSuccessResponse(
    this.paymentId,
    this.orderId,
    this.signature, [
    this.data,
  ]);

  Map<String, dynamic> toMap() {
    return {
      'razorpay_payment_id': paymentId,
      'razorpay_order_id': orderId,
      'razorpay_signature': signature,
      if (data != null) ...data!,
    };
  }
}

class PaymentFailureResponse {
  final int? code;
  final String? message;
  final Map<String, dynamic>? data;

  PaymentFailureResponse(
    this.code,
    this.message, [
    this.data,
  ]);

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'message': message,
      if (data != null) ...data!,
    };
  }
}

class ExternalWalletResponse {
  final String? walletName;
  final Map<String, dynamic>? data;

  ExternalWalletResponse(
    this.walletName, [
    this.data,
  ]);

  Map<String, dynamic> toMap() {
    return {
      'wallet_name': walletName,
      if (data != null) ...data!,
    };
  }
}
