import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/voice_conversation_entity.dart';
import '../../domain/entities/voice_preferences_entity.dart';
import '../../domain/repositories/voice_buddy_repository.dart';
import '../datasources/voice_buddy_remote_data_source.dart';
import '../models/voice_preferences_model.dart';

/// Implementation of VoiceBuddyRepository using Supabase.
class VoiceBuddyRepositoryImpl implements VoiceBuddyRepository {
  final VoiceBuddyRemoteDataSource _remoteDataSource;

  VoiceBuddyRepositoryImpl({
    required VoiceBuddyRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<Either<Failure, VoicePreferencesEntity>> getPreferences() async {
    try {
      final preferences = await _remoteDataSource.getPreferences();
      return Right(preferences);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, code: e.code));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message, code: e.code));
    } on ClientException catch (e) {
      return Left(ClientFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to get preferences: ${e.toString()}',
        code: 'GET_PREFERENCES_FAILED',
      ));
    }
  }

  @override
  Future<Either<Failure, VoicePreferencesEntity>> updatePreferences(
      VoicePreferencesEntity preferences) async {
    try {
      final model = VoicePreferencesModel.fromEntity(preferences);
      final updated = await _remoteDataSource.updatePreferences(model);
      return Right(updated);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, code: e.code));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message, code: e.code));
    } on ClientException catch (e) {
      return Left(ClientFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to update preferences: ${e.toString()}',
        code: 'UPDATE_PREFERENCES_FAILED',
      ));
    }
  }

  @override
  Future<Either<Failure, VoicePreferencesEntity>> resetPreferences() async {
    try {
      final preferences = await _remoteDataSource.resetPreferences();
      return Right(preferences);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, code: e.code));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message, code: e.code));
    } on ClientException catch (e) {
      return Left(ClientFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to reset preferences: ${e.toString()}',
        code: 'RESET_PREFERENCES_FAILED',
      ));
    }
  }

  @override
  Future<Either<Failure, VoiceQuotaEntity>> checkQuota() async {
    try {
      final quota = await _remoteDataSource.checkQuota();
      return Right(quota);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, code: e.code));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message, code: e.code));
    } on ClientException catch (e) {
      return Left(ClientFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to check quota: ${e.toString()}',
        code: 'CHECK_QUOTA_FAILED',
      ));
    }
  }

  @override
  Future<Either<Failure, void>> incrementUsage(String languageCode) async {
    try {
      // This is handled internally when starting a conversation
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, code: e.code));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to increment usage: ${e.toString()}',
        code: 'INCREMENT_USAGE_FAILED',
      ));
    }
  }

  @override
  Future<Either<Failure, VoiceConversationEntity>> startConversation({
    required String languageCode,
    required ConversationType conversationType,
    String? relatedStudyGuideId,
    String? relatedScripture,
  }) async {
    try {
      final conversation = await _remoteDataSource.startConversation(
        languageCode: languageCode,
        conversationType: conversationType.value,
        relatedStudyGuideId: relatedStudyGuideId,
        relatedScripture: relatedScripture,
      );
      return Right(conversation);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, code: e.code));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message, code: e.code));
    } on ClientException catch (e) {
      return Left(ClientFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to start conversation: ${e.toString()}',
        code: 'START_CONVERSATION_FAILED',
      ));
    }
  }

  @override
  Future<Either<Failure, List<VoiceConversationEntity>>>
      getConversationHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final conversations = await _remoteDataSource.getConversationHistory(
        limit: limit,
        offset: offset,
      );
      return Right(conversations);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, code: e.code));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message, code: e.code));
    } on ClientException catch (e) {
      return Left(ClientFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to get conversation history: ${e.toString()}',
        code: 'GET_HISTORY_FAILED',
      ));
    }
  }

  @override
  Future<Either<Failure, VoiceConversationEntity>> getConversation(
      String conversationId) async {
    try {
      final conversation =
          await _remoteDataSource.getConversationById(conversationId);
      return Right(conversation);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, code: e.code));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message, code: e.code));
    } on ClientException catch (e) {
      return Left(ClientFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to get conversation: ${e.toString()}',
        code: 'GET_CONVERSATION_FAILED',
      ));
    }
  }

  @override
  Future<Either<Failure, void>> endConversation({
    required String conversationId,
    int? rating,
    String? feedbackText,
    bool? wasHelpful,
  }) async {
    try {
      await _remoteDataSource.endConversation(
        conversationId: conversationId,
        rating: rating,
        feedbackText: feedbackText,
        wasHelpful: wasHelpful,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, code: e.code));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message, code: e.code));
    } on ClientException catch (e) {
      return Left(ClientFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to end conversation: ${e.toString()}',
        code: 'END_CONVERSATION_FAILED',
      ));
    }
  }

  @override
  Future<Either<Failure, ConversationMessageEntity>> saveMessage({
    required String conversationId,
    required int messageOrder,
    required MessageRole role,
    required String contentText,
    required String contentLanguage,
    double? audioDurationSeconds,
    double? transcriptionConfidence,
    String? llmModelUsed,
    int? llmTokensUsed,
    List<String>? scriptureReferences,
  }) async {
    try {
      final message = await _remoteDataSource.addMessage(
        conversationId: conversationId,
        role: role.value,
        contentText: contentText,
        contentLanguage: contentLanguage,
        audioDurationSeconds: audioDurationSeconds,
        transcriptionConfidence: transcriptionConfidence,
        llmModelUsed: llmModelUsed,
        llmTokensUsed: llmTokensUsed,
        scriptureReferences: scriptureReferences,
      );
      return Right(message);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, code: e.code));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message, code: e.code));
    } on ClientException catch (e) {
      return Left(ClientFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to save message: ${e.toString()}',
        code: 'SAVE_MESSAGE_FAILED',
      ));
    }
  }
}
