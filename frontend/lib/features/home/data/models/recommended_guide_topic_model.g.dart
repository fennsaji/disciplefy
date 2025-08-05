// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recommended_guide_topic_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecommendedGuideTopicModel _$RecommendedGuideTopicModelFromJson(Map<String, dynamic> json) =>
    RecommendedGuideTopicModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      difficultyLevel: json['difficulty_level'] as String,
      estimatedDuration: json['estimated_duration'] as String,
      keyVerses: (json['key_verses'] as List<dynamic>).map((e) => e as String).toList(),
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
      isFeatured: json['is_featured'] as bool? ?? false,
      createdAt: json['created_at'] == null ? null : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$RecommendedGuideTopicModelToJson(RecommendedGuideTopicModel instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'category': instance.category,
      'tags': instance.tags,
      'is_featured': instance.isFeatured,
      'created_at': instance.createdAt.toIso8601String(),
      'difficulty_level': instance.difficultyLevel,
      'estimated_duration': instance.estimatedDuration,
      'key_verses': instance.keyVerses,
    };

RecommendedGuideTopicsResponse _$RecommendedGuideTopicsResponseFromJson(Map<String, dynamic> json) =>
    RecommendedGuideTopicsResponse(
      topics: (json['topics'] as List<dynamic>)
          .map((e) => RecommendedGuideTopicModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num?)?.toInt(),
      totalPages: (json['totalPages'] as num?)?.toInt(),
    );

Map<String, dynamic> _$RecommendedGuideTopicsResponseToJson(RecommendedGuideTopicsResponse instance) =>
    <String, dynamic>{
      'topics': instance.topics,
      'total': instance.total,
      'page': instance.page,
      'totalPages': instance.totalPages,
    };
