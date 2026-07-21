// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_guide_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SavedGuideModel _$SavedGuideModelFromJson(Map<String, dynamic> json) =>
    SavedGuideModel(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      typeString: json['type'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAccessedAt: DateTime.parse(json['lastAccessedAt'] as String),
      isSaved: json['isSaved'] as bool,
      studyMode: json['studyMode'] as String?,
      verseReference: json['verseReference'] as String?,
      topicName: json['topicName'] as String?,
      summary: json['summary'] as String?,
      interpretation: json['interpretation'] as String?,
      context: json['context'] as String?,
      relatedVerses: (json['relatedVerses'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      reflectionQuestions: (json['reflectionQuestions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      prayerPoints: (json['prayerPoints'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      passage: json['passage'] as String?,
      interpretationInsights: (json['interpretationInsights'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      summaryInsights: (json['summaryInsights'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      reflectionAnswers: (json['reflectionAnswers'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      contextQuestion: json['contextQuestion'] as String?,
      summaryQuestion: json['summaryQuestion'] as String?,
      relatedVersesQuestion: json['relatedVersesQuestion'] as String?,
      reflectionQuestion: json['reflectionQuestion'] as String?,
      prayerQuestion: json['prayerQuestion'] as String?,
    );

Map<String, dynamic> _$SavedGuideModelToJson(SavedGuideModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'content': instance.content,
      'summary': instance.summary,
      'interpretation': instance.interpretation,
      'context': instance.context,
      'relatedVerses': instance.relatedVerses,
      'reflectionQuestions': instance.reflectionQuestions,
      'prayerPoints': instance.prayerPoints,
      'interpretationInsights': instance.interpretationInsights,
      'contextQuestion': instance.contextQuestion,
      'summaryQuestion': instance.summaryQuestion,
      'relatedVersesQuestion': instance.relatedVersesQuestion,
      'reflectionQuestion': instance.reflectionQuestion,
      'prayerQuestion': instance.prayerQuestion,
      'summaryInsights': instance.summaryInsights,
      'reflectionAnswers': instance.reflectionAnswers,
      'studyMode': instance.studyMode,
      'passage': instance.passage,
      'type': instance.typeString,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastAccessedAt': instance.lastAccessedAt.toIso8601String(),
      'isSaved': instance.isSaved,
      'verseReference': instance.verseReference,
      'topicName': instance.topicName,
    };
