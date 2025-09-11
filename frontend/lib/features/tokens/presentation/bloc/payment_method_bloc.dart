import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/saved_payment_method.dart';
import '../../domain/usecases/get_payment_methods.dart';
import '../../domain/usecases/save_payment_method.dart';
import '../../domain/usecases/set_default_payment_method.dart';
import '../../domain/usecases/delete_payment_method.dart';
import '../../domain/usecases/get_payment_preferences.dart';
import '../../domain/usecases/update_payment_preferences.dart';

part 'payment_method_event.dart';
part 'payment_method_state.dart';

class PaymentMethodBloc extends Bloc<PaymentMethodEvent, PaymentMethodState> {
  final GetPaymentMethods getPaymentMethods;
  final SavePaymentMethod savePaymentMethod;
  final SetDefaultPaymentMethod setDefaultPaymentMethod;
  final DeletePaymentMethod deletePaymentMethod;
  final GetPaymentPreferences getPaymentPreferences;
  final UpdatePaymentPreferences updatePaymentPreferences;

  PaymentMethodBloc({
    required this.getPaymentMethods,
    required this.savePaymentMethod,
    required this.setDefaultPaymentMethod,
    required this.deletePaymentMethod,
    required this.getPaymentPreferences,
    required this.updatePaymentPreferences,
  }) : super(PaymentMethodInitial()) {
    on<LoadPaymentMethods>(_onLoadPaymentMethods);
    on<SavePaymentMethodEvent>(_onSavePaymentMethod);
    on<SetDefaultPaymentMethodEvent>(_onSetDefaultPaymentMethod);
    on<DeletePaymentMethodEvent>(_onDeletePaymentMethod);
    on<LoadPaymentPreferences>(_onLoadPaymentPreferences);
    on<UpdatePaymentPreferencesEvent>(_onUpdatePaymentPreferences);
  }

  Future<void> _onLoadPaymentMethods(
    LoadPaymentMethods event,
    Emitter<PaymentMethodState> emit,
  ) async {
    emit(PaymentMethodLoading());

    final result = await getPaymentMethods(NoParams());

    result.fold(
      (failure) => emit(PaymentMethodError(_mapFailureToMessage(failure))),
      (paymentMethods) => emit(PaymentMethodsLoaded(paymentMethods)),
    );
  }

  Future<void> _onSavePaymentMethod(
    SavePaymentMethodEvent event,
    Emitter<PaymentMethodState> emit,
  ) async {
    emit(PaymentMethodSaving());

    final result = await savePaymentMethod(SavePaymentMethodParams(
      methodType: event.methodType,
      provider: event.provider,
      token: event.token,
      lastFour: event.lastFour,
      brand: event.brand,
      displayName: event.displayName,
      isDefault: event.isDefault,
      expiryMonth: event.expiryMonth,
      expiryYear: event.expiryYear,
    ));

    result.fold(
      (failure) => emit(PaymentMethodError(_mapFailureToMessage(failure))),
      (savedMethod) {
        emit(PaymentMethodSaved(savedMethod));
        add(LoadPaymentMethods());
      },
    );
  }

  Future<void> _onSetDefaultPaymentMethod(
    SetDefaultPaymentMethodEvent event,
    Emitter<PaymentMethodState> emit,
  ) async {
    emit(PaymentMethodUpdating());

    final result = await setDefaultPaymentMethod(
      SetDefaultPaymentMethodParams(paymentMethodId: event.paymentMethodId),
    );

    result.fold(
      (failure) => emit(PaymentMethodError(_mapFailureToMessage(failure))),
      (_) {
        emit(PaymentMethodDefaultSet());
        add(LoadPaymentMethods());
      },
    );
  }

  Future<void> _onDeletePaymentMethod(
    DeletePaymentMethodEvent event,
    Emitter<PaymentMethodState> emit,
  ) async {
    emit(PaymentMethodDeleting());

    final result = await deletePaymentMethod(
      DeletePaymentMethodParams(paymentMethodId: event.paymentMethodId),
    );

    result.fold(
      (failure) => emit(PaymentMethodError(_mapFailureToMessage(failure))),
      (_) {
        emit(PaymentMethodDeleted());
        add(LoadPaymentMethods());
      },
    );
  }

  Future<void> _onLoadPaymentPreferences(
    LoadPaymentPreferences event,
    Emitter<PaymentMethodState> emit,
  ) async {
    emit(PaymentPreferencesLoading());

    final result = await getPaymentPreferences(NoParams());

    result.fold(
      (failure) => emit(PaymentMethodError(_mapFailureToMessage(failure))),
      (preferences) => emit(PaymentPreferencesLoaded(preferences)),
    );
  }

  Future<void> _onUpdatePaymentPreferences(
    UpdatePaymentPreferencesEvent event,
    Emitter<PaymentMethodState> emit,
  ) async {
    emit(PaymentPreferencesUpdating());

    final result =
        await updatePaymentPreferences(UpdatePaymentPreferencesParams(
      autoSavePaymentMethods: event.autoSavePaymentMethods,
      preferredWallet: event.preferredWallet,
      enableOneClickPurchase: event.enableOneClickPurchase,
      defaultPaymentType: event.defaultPaymentType,
    ));

    result.fold(
      (failure) => emit(PaymentMethodError(_mapFailureToMessage(failure))),
      (preferences) {
        emit(PaymentPreferencesUpdated(preferences));
        add(LoadPaymentPreferences());
      },
    );
  }

  String _mapFailureToMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ServerFailure:
        return 'Server error occurred';
      case NetworkFailure:
        return 'Network connection failed';
      case DatabaseFailure:
        return 'Database error occurred';
      case AuthenticationFailure:
        return 'Authentication failed';
      case ValidationFailure:
        return 'Invalid payment method data';
      default:
        return 'An unexpected error occurred';
    }
  }
}
