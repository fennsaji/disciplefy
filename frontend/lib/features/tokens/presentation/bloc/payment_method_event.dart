part of 'payment_method_bloc.dart';

abstract class PaymentMethodEvent extends Equatable {
  const PaymentMethodEvent();

  @override
  List<Object?> get props => [];
}

class LoadPaymentMethods extends PaymentMethodEvent {}

class SavePaymentMethodEvent extends PaymentMethodEvent {
  final String methodType;
  final String provider;
  final String token;
  final String? lastFour;
  final String? brand;
  final String? displayName;
  final bool isDefault;
  final int? expiryMonth;
  final int? expiryYear;

  const SavePaymentMethodEvent({
    required this.methodType,
    required this.provider,
    required this.token,
    this.lastFour,
    this.brand,
    this.displayName,
    this.isDefault = false,
    this.expiryMonth,
    this.expiryYear,
  });

  @override
  List<Object?> get props => [
        methodType,
        provider,
        token,
        lastFour,
        brand,
        displayName,
        isDefault,
        expiryMonth,
        expiryYear,
      ];
}

class SetDefaultPaymentMethodEvent extends PaymentMethodEvent {
  final String paymentMethodId;

  const SetDefaultPaymentMethodEvent({required this.paymentMethodId});

  @override
  List<Object> get props => [paymentMethodId];
}

class DeletePaymentMethodEvent extends PaymentMethodEvent {
  final String paymentMethodId;

  const DeletePaymentMethodEvent({required this.paymentMethodId});

  @override
  List<Object> get props => [paymentMethodId];
}

class LoadPaymentPreferences extends PaymentMethodEvent {}

class UpdatePaymentPreferencesEvent extends PaymentMethodEvent {
  final bool? autoSavePaymentMethods;
  final String? preferredWallet;
  final bool? enableOneClickPurchase;
  final String? defaultPaymentType;

  const UpdatePaymentPreferencesEvent({
    this.autoSavePaymentMethods,
    this.preferredWallet,
    this.enableOneClickPurchase,
    this.defaultPaymentType,
  });

  @override
  List<Object?> get props => [
        autoSavePaymentMethods,
        preferredWallet,
        enableOneClickPurchase,
        defaultPaymentType,
      ];
}
