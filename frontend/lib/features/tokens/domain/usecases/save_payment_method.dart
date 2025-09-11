import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/saved_payment_method.dart';
import '../repositories/payment_method_repository.dart';

class SavePaymentMethod implements UseCase<String, SavePaymentMethodParams> {
  final PaymentMethodRepository repository;

  SavePaymentMethod(this.repository);

  @override
  Future<Either<Failure, String>> call(SavePaymentMethodParams params) async {
    return await repository.savePaymentMethod(
      methodType: params.methodType,
      provider: params.provider,
      token: params.token,
      lastFour: params.lastFour,
      brand: params.brand,
      displayName: params.displayName,
      isDefault: params.isDefault,
      expiryMonth: params.expiryMonth,
      expiryYear: params.expiryYear,
    );
  }
}

class SavePaymentMethodParams extends Equatable {
  final String methodType;
  final String provider;
  final String token;
  final String? lastFour;
  final String? brand;
  final String? displayName;
  final bool isDefault;
  final int? expiryMonth;
  final int? expiryYear;

  const SavePaymentMethodParams({
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
