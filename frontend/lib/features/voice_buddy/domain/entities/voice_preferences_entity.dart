import 'package:equatable/equatable.dart';

/// Entity representing user voice preferences.
class VoicePreferencesEntity extends Equatable {
  final String? id;
  final String userId;
  final String preferredLanguage;
  final bool autoDetectLanguage;
  final VoiceGender ttsVoiceGender;
  final double speakingRate;
  final double pitch;
  final bool autoPlayResponse;
  final bool showTranscription;
  final bool continuousMode;
  final bool useStudyContext;
  final bool citeScriptureReferences;
  final bool notifyDailyQuotaReached;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VoicePreferencesEntity({
    this.id,
    required this.userId,
    this.preferredLanguage = 'en-US',
    this.autoDetectLanguage = true,
    this.ttsVoiceGender = VoiceGender.female,
    this.speakingRate = 0.95,
    this.pitch = 0.0,
    this.autoPlayResponse = true,
    this.showTranscription = true,
    this.continuousMode = false,
    this.useStudyContext = true,
    this.citeScriptureReferences = true,
    this.notifyDailyQuotaReached = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Default preferences for a new user.
  factory VoicePreferencesEntity.defaults(String userId) {
    return VoicePreferencesEntity(userId: userId);
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        preferredLanguage,
        autoDetectLanguage,
        ttsVoiceGender,
        speakingRate,
        pitch,
        autoPlayResponse,
        showTranscription,
        continuousMode,
        useStudyContext,
        citeScriptureReferences,
        notifyDailyQuotaReached,
        createdAt,
        updatedAt,
      ];

  VoicePreferencesEntity copyWith({
    String? id,
    String? userId,
    String? preferredLanguage,
    bool? autoDetectLanguage,
    VoiceGender? ttsVoiceGender,
    double? speakingRate,
    double? pitch,
    bool? autoPlayResponse,
    bool? showTranscription,
    bool? continuousMode,
    bool? useStudyContext,
    bool? citeScriptureReferences,
    bool? notifyDailyQuotaReached,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VoicePreferencesEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      autoDetectLanguage: autoDetectLanguage ?? this.autoDetectLanguage,
      ttsVoiceGender: ttsVoiceGender ?? this.ttsVoiceGender,
      speakingRate: speakingRate ?? this.speakingRate,
      pitch: pitch ?? this.pitch,
      autoPlayResponse: autoPlayResponse ?? this.autoPlayResponse,
      showTranscription: showTranscription ?? this.showTranscription,
      continuousMode: continuousMode ?? this.continuousMode,
      useStudyContext: useStudyContext ?? this.useStudyContext,
      citeScriptureReferences:
          citeScriptureReferences ?? this.citeScriptureReferences,
      notifyDailyQuotaReached:
          notifyDailyQuotaReached ?? this.notifyDailyQuotaReached,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Voice gender preference for TTS.
enum VoiceGender {
  male,
  female,
}

extension VoiceGenderExtension on VoiceGender {
  String get value {
    switch (this) {
      case VoiceGender.male:
        return 'male';
      case VoiceGender.female:
        return 'female';
    }
  }

  static VoiceGender fromString(String value) {
    switch (value) {
      case 'male':
        return VoiceGender.male;
      case 'female':
        return VoiceGender.female;
      default:
        return VoiceGender.female;
    }
  }
}

/// Entity representing voice usage quota information.
class VoiceQuotaEntity extends Equatable {
  final bool canStart;
  final int quotaLimit;
  final int quotaUsed;
  final int quotaRemaining;
  final String tier;

  const VoiceQuotaEntity({
    required this.canStart,
    required this.quotaLimit,
    required this.quotaUsed,
    required this.quotaRemaining,
    required this.tier,
  });

  @override
  List<Object?> get props => [
        canStart,
        quotaLimit,
        quotaUsed,
        quotaRemaining,
        tier,
      ];
}
