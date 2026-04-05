import 'dart:async';
import '../connectivity/connectivity_bloc.dart';
import '../utils/logger.dart';
import '../../features/saved_guides/data/services/saved_guides_sync_service.dart';

class ConnectivitySyncService {
  final ConnectivityBloc _connectivityBloc;
  final SavedGuidesSyncService _savedGuidesSyncService;
  StreamSubscription? _subscription;

  ConnectivitySyncService({
    required ConnectivityBloc connectivityBloc,
    required SavedGuidesSyncService savedGuidesSyncService,
  })  : _connectivityBloc = connectivityBloc,
        _savedGuidesSyncService = savedGuidesSyncService;

  void initialize() {
    _subscription = _connectivityBloc.stream.listen((state) {
      if (state is ConnectivityOnline) {
        _flushQueues();
      }
    });
  }

  Future<void> _flushQueues() async {
    Logger.info('[ConnectivitySyncService] Online — flushing sync queues');
    await _savedGuidesSyncService.syncWithRemote();
  }

  void dispose() {
    _subscription?.cancel();
  }
}
