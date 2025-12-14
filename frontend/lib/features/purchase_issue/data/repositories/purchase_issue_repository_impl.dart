import 'dart:io';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/purchase_issue_entity.dart';
import '../../domain/repositories/purchase_issue_repository.dart';
import '../datasources/purchase_issue_remote_datasource.dart';

/// Implementation of PurchaseIssueRepository
class PurchaseIssueRepositoryImpl implements PurchaseIssueRepository {
  final PurchaseIssueRemoteDataSource remoteDataSource;

  PurchaseIssueRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, PurchaseIssueResponse>> submitIssueReport(
    PurchaseIssueEntity issue,
  ) async {
    try {
      final response = await remoteDataSource.submitIssueReport(issue);

      if (response.success) {
        return Right(response);
      } else {
        return Left(ServerFailure(
          message: response.message.isNotEmpty
              ? response.message
              : 'Failed to submit issue report',
        ));
      }
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on SocketException catch (e) {
      return Left(
        NetworkFailure(message: 'Network connection failed: ${e.message}'),
      );
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, ScreenshotUploadResponse>> uploadScreenshot({
    required String fileName,
    required Uint8List fileBytes,
    required String mimeType,
  }) async {
    try {
      final response = await remoteDataSource.uploadScreenshot(
        fileName: fileName,
        fileBytes: fileBytes,
        mimeType: mimeType,
      );

      if (response.success) {
        return Right(response);
      } else {
        return Left(ServerFailure(
          message: response.error ?? 'Failed to upload screenshot',
        ));
      }
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on SocketException catch (e) {
      return Left(
        NetworkFailure(message: 'Network connection failed: ${e.message}'),
      );
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }
}
