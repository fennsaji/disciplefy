part of 'payment_method_bloc.dart';

abstract class PaymentMethodState extends Equatable {
  const PaymentMethodState();

  @override
  List<Object?> get props => [];
}

class PaymentMethodInitial extends PaymentMethodState {}

class PaymentMethodLoading extends PaymentMethodState {}

class PaymentMethodsLoaded extends PaymentMethodState {
  final List<SavedPaymentMethod> paymentMethods;

  const PaymentMethodsLoaded(this.paymentMethods);

  @override
  List<Object> get props => [paymentMethods];
}

class PaymentMethodSaving extends PaymentMethodState {}

class PaymentMethodSaved extends PaymentMethodState {
  final String paymentMethodId;

  const PaymentMethodSaved(this.paymentMethodId);

  @override
  List<Object> get props => [paymentMethodId];
}

class PaymentMethodUpdating extends PaymentMethodState {}

class PaymentMethodDefaultSet extends PaymentMethodState {}

class PaymentMethodDeleting extends PaymentMethodState {}

class PaymentMethodDeleted extends PaymentMethodState {}

class PaymentPreferencesLoading extends PaymentMethodState {}

class PaymentPreferencesLoaded extends PaymentMethodState {
  final PaymentPreferences preferences;

  const PaymentPreferencesLoaded(this.preferences);

  @override
  List<Object> get props => [preferences];
}

class PaymentPreferencesUpdating extends PaymentMethodState {}

class PaymentPreferencesUpdated extends PaymentMethodState {
  final PaymentPreferences preferences;

  const PaymentPreferencesUpdated(this.preferences);

  @override
  List<Object> get props => [preferences];
}

class PaymentMethodError extends PaymentMethodState {
  final String message;

  const PaymentMethodError(this.message);

  @override
  List<Object> get props => [message];
}
