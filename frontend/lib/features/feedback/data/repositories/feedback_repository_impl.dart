import 'dart:developer';
import 'package:dartz/dartz.dart';
import 'dart:io';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/feedback_entity.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../datasources/feedback_remote_datasource.dart';

/// Implementation of FeedbackRepository
class FeedbackRepositoryImpl implements FeedbackRepository {
  final FeedbackRemoteDataSource remoteDataSource;

  FeedbackRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, void>> submitFeedback(FeedbackEntity feedback) async {
    try {
      await remoteDataSource.submitFeedback(feedback);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on SocketException catch (e) {
      return Left(
          NetworkFailure(message: 'Network connection failed: ${e.message}'));
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> submitPositiveFeedback({
    String? studyGuideId,
    String? message,
    required UserContextEntity userContext,
  }) async {
    final feedback = FeedbackEntity(
      studyGuideId: studyGuideId,
      wasHelpful: true,
      message: message,
      category: 'general',
      userContext: userContext,
    );

    return await submitFeedback(feedback);
  }

  @override
  Future<Either<Failure, void>> submitNegativeFeedback({
    String? studyGuideId,
    required String message,
    String category = 'general',
    required UserContextEntity userContext,
  }) async {
    final feedback = FeedbackEntity(
      studyGuideId: studyGuideId,
      wasHelpful: false,
      message: message,
      category: category,
      userContext: userContext,
    );

    return await submitFeedback(feedback);
  }

  @override
  Future<Either<Failure, void>> submitGeneralFeedback({
    required bool wasHelpful,
    required String message,
    String category = 'general',
    required UserContextEntity userContext,
  }) async {
    final feedback = FeedbackEntity(
      wasHelpful: wasHelpful,
      message: message,
      category: category,
      userContext: userContext,
    );

    return await submitFeedback(feedback);
  }
}
