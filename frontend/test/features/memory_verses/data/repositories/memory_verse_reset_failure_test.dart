import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/error/exceptions.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/models/reset_progress_result.dart';
import 'package:disciplefy_bible_study/features/memory_verses/data/datasources/memory_verse_local_datasource.dart';
import 'package:disciplefy_bible_study/features/memory_verses/data/datasources/memory_verse_remote_datasource.dart';
import 'package:disciplefy_bible_study/features/memory_verses/data/repositories/memory_verse_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'memory_verse_reset_failure_test.mocks.dart';

@GenerateMocks([MemoryVerseRemoteDataSource, MemoryVerseLocalDataSource])
void main() {
  late MockMemoryVerseRemoteDataSource remoteDataSource;
  late MockMemoryVerseLocalDataSource localDataSource;
  late MemoryVerseRepositoryImpl repository;

  setUp(() {
    remoteDataSource = MockMemoryVerseRemoteDataSource();
    localDataSource = MockMemoryVerseLocalDataSource();
    repository = MemoryVerseRepositoryImpl(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
    );
  });

  group('resetMemoryProgress', () {
    test(
        'returns Right(ResetProgressResult) and clears the local cache on success',
        () async {
      const result = ResetProgressResult(
        scope: 'memory_verses',
        counts: {'verses_deleted': 5},
      );
      when(remoteDataSource.resetMemoryProgress())
          .thenAnswer((_) async => result);
      when(localDataSource.clearCache()).thenAnswer((_) async {});

      final actual = await repository.resetMemoryProgress();

      expect(actual, const Right<Failure, ResetProgressResult>(result));
      verify(localDataSource.clearCache()).called(1);
    });

    test(
        'returns Right(ResetProgressResult) when the remote reset succeeds '
        'but clearCache() throws afterwards', () async {
      const result = ResetProgressResult(
        scope: 'memory_verses',
        counts: {'verses_deleted': 5},
      );
      when(remoteDataSource.resetMemoryProgress())
          .thenAnswer((_) async => result);
      when(localDataSource.clearCache())
          .thenThrow(Exception('Hive box I/O error'));

      final actual = await repository.resetMemoryProgress();

      // The server-side reset is irreversible and already succeeded, so a
      // cache-clear failure must not be reported as a failed reset.
      expect(actual, const Right<Failure, ResetProgressResult>(result));
      verify(localDataSource.clearCache()).called(1);
    });

    test(
        'returns Left(RateLimitFailure) and leaves the cache intact when RateLimitException is thrown',
        () async {
      when(remoteDataSource.resetMemoryProgress()).thenThrow(
        const RateLimitException(
          message: 'You have reached the reset limit.',
          code: 'RATE_LIMIT_EXCEEDED',
        ),
      );

      final actual = await repository.resetMemoryProgress();

      expect(actual.isLeft(), isTrue);
      actual.fold(
        (failure) => expect(failure, isA<RateLimitFailure>()),
        (_) => fail('expected a Left(RateLimitFailure)'),
      );
      verifyNever(localDataSource.clearCache());
    });

    test(
        'returns Left(AuthenticationFailure) and leaves the cache intact when AuthenticationException is thrown',
        () async {
      when(remoteDataSource.resetMemoryProgress()).thenThrow(
        const AuthenticationException(
          message: 'Authentication required.',
          code: 'UNAUTHORIZED',
        ),
      );

      final actual = await repository.resetMemoryProgress();

      expect(actual.isLeft(), isTrue);
      actual.fold(
        (failure) => expect(failure, isA<AuthenticationFailure>()),
        (_) => fail('expected a Left(AuthenticationFailure)'),
      );
      verifyNever(localDataSource.clearCache());
    });

    test(
        'returns Left(NetworkFailure) and leaves the cache intact when NetworkException is thrown',
        () async {
      when(remoteDataSource.resetMemoryProgress()).thenThrow(
        const NetworkException(
          message: 'Offline.',
          code: 'NETWORK_ERROR',
        ),
      );

      final actual = await repository.resetMemoryProgress();

      expect(actual.isLeft(), isTrue);
      actual.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('expected a Left(NetworkFailure)'),
      );
      verifyNever(localDataSource.clearCache());
    });

    test(
        'returns Left(ServerFailure) when an unrecognised non-AppException error is thrown',
        () async {
      when(remoteDataSource.resetMemoryProgress())
          .thenThrow(const FormatException('unexpected'));

      final actual = await repository.resetMemoryProgress();

      expect(actual.isLeft(), isTrue);
      actual.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('expected a Left(ServerFailure)'),
      );
      verifyNever(localDataSource.clearCache());
    });
  });
}
