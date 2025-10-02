import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/network_info.dart';
import '../data/datasources/token_remote_data_source.dart';
import '../data/repositories/token_repository_impl.dart';
import '../data/repositories/payment_method_repository_impl.dart';
import '../domain/repositories/token_repository.dart';
import '../domain/repositories/payment_method_repository.dart';
import '../domain/usecases/get_token_status.dart';
import '../domain/usecases/get_payment_methods.dart';
import '../domain/usecases/save_payment_method.dart';
import '../domain/usecases/set_default_payment_method.dart';
import '../domain/usecases/delete_payment_method.dart';
import '../domain/usecases/get_payment_preferences.dart';
import '../domain/usecases/update_payment_preferences.dart';
import '../domain/usecases/confirm_payment.dart';
import '../domain/usecases/create_payment_order.dart';
import '../domain/usecases/get_purchase_history.dart';
import '../domain/usecases/get_purchase_statistics.dart';
import '../presentation/bloc/token_bloc.dart';
import '../presentation/bloc/payment_method_bloc.dart';

/// Register all token-related dependencies
void registerTokenDependencies(GetIt sl) {
  //! Token Data Sources
  sl.registerLazySingleton<TokenRemoteDataSource>(
    () => TokenRemoteDataSourceImpl(
      supabaseClient: sl<SupabaseClient>(),
    ),
  );

  //! Token Repositories
  sl.registerLazySingleton<TokenRepository>(
    () => TokenRepositoryImpl(
      remoteDataSource: sl<TokenRemoteDataSource>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  sl.registerLazySingleton<PaymentMethodRepository>(
    () => PaymentMethodRepositoryImpl(
      remoteDataSource: sl<TokenRemoteDataSource>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  //! Token Use Cases
  sl.registerLazySingleton(() => GetTokenStatus(sl<TokenRepository>()));
  sl.registerLazySingleton(() => ConfirmPayment(sl<TokenRepository>()));
  sl.registerLazySingleton(() => CreatePaymentOrder(sl<TokenRepository>()));
  sl.registerLazySingleton(() => GetPurchaseHistory(sl<TokenRepository>()));
  sl.registerLazySingleton(() => GetPurchaseStatistics(sl<TokenRepository>()));

  //! Payment Method Use Cases
  sl.registerLazySingleton(
    () => GetPaymentMethods(sl<PaymentMethodRepository>()),
  );
  sl.registerLazySingleton(
    () => SavePaymentMethod(sl<PaymentMethodRepository>()),
  );
  sl.registerLazySingleton(
    () => SetDefaultPaymentMethod(sl<PaymentMethodRepository>()),
  );
  sl.registerLazySingleton(
    () => DeletePaymentMethod(sl<PaymentMethodRepository>()),
  );
  sl.registerLazySingleton(
    () => GetPaymentPreferences(sl<PaymentMethodRepository>()),
  );
  sl.registerLazySingleton(
    () => UpdatePaymentPreferences(sl<PaymentMethodRepository>()),
  );

  //! Token BLoCs
  sl.registerFactory(() => TokenBloc(
        getTokenStatus: sl<GetTokenStatus>(),
        confirmPayment: sl<ConfirmPayment>(),
        createPaymentOrder: sl<CreatePaymentOrder>(),
        getPurchaseHistory: sl<GetPurchaseHistory>(),
        getPurchaseStatistics: sl<GetPurchaseStatistics>(),
      ));

  sl.registerFactory(() => PaymentMethodBloc(
        getPaymentMethods: sl<GetPaymentMethods>(),
        savePaymentMethod: sl<SavePaymentMethod>(),
        setDefaultPaymentMethod: sl<SetDefaultPaymentMethod>(),
        deletePaymentMethod: sl<DeletePaymentMethod>(),
        getPaymentPreferences: sl<GetPaymentPreferences>(),
        updatePaymentPreferences: sl<UpdatePaymentPreferences>(),
      ));
}
