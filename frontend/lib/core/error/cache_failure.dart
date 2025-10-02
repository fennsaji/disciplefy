import 'failures.dart';

/// Cache-related failure
class CacheFailure extends Failure {
  const CacheFailure({String? message})
      : super(
            message: message ?? 'Cache operation failed', code: 'CACHE_ERROR');

  @override
  List<Object?> get props => [message];
}
