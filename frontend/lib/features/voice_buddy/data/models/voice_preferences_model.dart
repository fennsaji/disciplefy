import '../../domain/entities/voice_preferences_entity.dart';

/// Data model for VoicePreferences with JSON serialization.
class VoicePreferencesModel extends VoicePreferencesEntity {
  const VoicePreferencesModel({
    super.id,
    required super.userId,
    super.preferredLanguage,
    super.autoDetectLanguage,
    super.ttsVoiceGender,
    super.speakingRate,
    super.pitch,
    super.autoPlayResponse,
    super.showTranscription,
    super.continuousMode,
    super.useStudyContext,
    super.citeScriptureReferences,
    super.notifyDailyQuotaReached,
    super.createdAt,
    super.updatedAt,
  });

  factory VoicePreferencesModel.fromJson(Map<String, dynamic> json) {
    return VoicePreferencesModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      preferredLanguage: json['preferred_language'] as String? ?? 'en-US',
      autoDetectLanguage: json['auto_detect_language'] as bool? ?? true,
      ttsVoiceGender: VoiceGenderExtension.fromString(
          json['tts_voice_gender'] as String? ?? 'female'),
      speakingRate: (json['speaking_rate'] as num?)?.toDouble() ?? 0.95,
      pitch: (json['pitch'] as num?)?.toDouble() ?? 0.0,
      autoPlayResponse: json['auto_play_response'] as bool? ?? true,
      showTranscription: json['show_transcription'] as bool? ?? true,
      continuousMode: json['continuous_mode'] as bool? ?? true,
      useStudyContext: json['use_study_context'] as bool? ?? true,
      citeScriptureReferences:
          json['cite_scripture_references'] as bool? ?? true,
      notifyDailyQuotaReached:
          json['notify_daily_quota_reached'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'preferred_language': preferredLanguage,
      'auto_detect_language': autoDetectLanguage,
      'tts_voice_gender': ttsVoiceGender.value,
      'speaking_rate': speakingRate,
      'pitch': pitch,
      'auto_play_response': autoPlayResponse,
      'show_transcription': showTranscription,
      'continuous_mode': continuousMode,
      'use_study_context': useStudyContext,
      'cite_scripture_references': citeScriptureReferences,
      'notify_daily_quota_reached': notifyDailyQuotaReached,
    };
  }

  factory VoicePreferencesModel.fromEntity(VoicePreferencesEntity entity) {
    return VoicePreferencesModel(
      id: entity.id,
      userId: entity.userId,
      preferredLanguage: entity.preferredLanguage,
      autoDetectLanguage: entity.autoDetectLanguage,
      ttsVoiceGender: entity.ttsVoiceGender,
      speakingRate: entity.speakingRate,
      pitch: entity.pitch,
      autoPlayResponse: entity.autoPlayResponse,
      showTranscription: entity.showTranscription,
      continuousMode: entity.continuousMode,
      useStudyContext: entity.useStudyContext,
      citeScriptureReferences: entity.citeScriptureReferences,
      notifyDailyQuotaReached: entity.notifyDailyQuotaReached,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}

/// Data model for VoiceQuota with JSON serialization.
class VoiceQuotaModel extends VoiceQuotaEntity {
  const VoiceQuotaModel({
    required super.canStart,
    required super.quotaLimit,
    required super.quotaUsed,
    required super.quotaRemaining,
    required super.tier,
  });

  factory VoiceQuotaModel.fromJson(Map<String, dynamic> json) {
    return VoiceQuotaModel(
      canStart: json['can_start'] as bool? ?? false,
      quotaLimit: json['quota_limit'] as int? ?? 0,
      quotaUsed: json['quota_used'] as int? ?? 0,
      quotaRemaining: json['quota_remaining'] as int? ?? 0,
      tier: json['tier'] as String? ?? 'free',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'can_start': canStart,
      'quota_limit': quotaLimit,
      'quota_used': quotaUsed,
      'quota_remaining': quotaRemaining,
      'tier': tier,
    };
  }
}
