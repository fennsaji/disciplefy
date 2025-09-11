import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/saved_payment_method.dart';
import '../repositories/payment_method_repository.dart';

class UpdatePaymentPreferences
    implements UseCase<PaymentPreferences, UpdatePaymentPreferencesParams> {
  final PaymentMethodRepository repository;

  UpdatePaymentPreferences(this.repository);

  @override
  Future<Either<Failure, PaymentPreferences>> call(
      UpdatePaymentPreferencesParams params) async {
    return await repository.updatePaymentPreferences(
      autoSavePaymentMethods: params.autoSavePaymentMethods,
      preferredWallet: params.preferredWallet,
      enableOneClickPurchase: params.enableOneClickPurchase,
      defaultPaymentType: params.defaultPaymentType,
    );
  }
}

class UpdatePaymentPreferencesParams extends Equatable {
  final bool? autoSavePaymentMethods;
  final String? preferredWallet;
  final bool? enableOneClickPurchase;
  final String? defaultPaymentType;

  const UpdatePaymentPreferencesParams({
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
