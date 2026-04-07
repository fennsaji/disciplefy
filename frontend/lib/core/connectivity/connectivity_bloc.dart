import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../network/network_info.dart';

part 'connectivity_event.dart';
part 'connectivity_state.dart';

class ConnectivityBloc extends Bloc<ConnectivityEvent, ConnectivityState> {
  final NetworkInfo _networkInfo;
  StreamSubscription? _connectivitySubscription;

  ConnectivityBloc({required NetworkInfo networkInfo})
      : _networkInfo = networkInfo,
        super(ConnectivityInitial()) {
    on<ConnectivityStatusChanged>(_onStatusChanged);
    _subscribeToConnectivity();
    _checkInitialStatus();
  }

  /// Immediately checks current connectivity so the bloc emits a real state
  /// before any BLoC fires its first load event (avoids the race condition
  /// where [ConnectivityInitial] is misread as online).
  void _checkInitialStatus() async {
    final isOnline = await _networkInfo.isConnected;
    add(ConnectivityStatusChanged(isOnline: isOnline));
  }

  void _subscribeToConnectivity() {
    _connectivitySubscription =
        _networkInfo.connectivityStream.listen((results) {
      final isOnline =
          results.isNotEmpty && !results.every((r) => r.name == 'none');
      add(ConnectivityStatusChanged(isOnline: isOnline));
    });
  }

  void _onStatusChanged(
    ConnectivityStatusChanged event,
    Emitter<ConnectivityState> emit,
  ) {
    emit(event.isOnline ? ConnectivityOnline() : ConnectivityOffline());
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }
}
