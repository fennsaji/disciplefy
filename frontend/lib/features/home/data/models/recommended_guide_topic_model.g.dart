// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recommended_guide_topic_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecommendedGuideTopicModel _$RecommendedGuideTopicModelFromJson(
        Map<String, dynamic> json) =>
    RecommendedGuideTopicModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      keyVerses: (json['key_verses'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const <String>[],
      englishTitle: json['english_title'] as String?,
      englishDescription: json['english_description'] as String?,
      englishCategory: json['english_category'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$RecommendedGuideTopicModelToJson(
        RecommendedGuideTopicModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'category': instance.category,
      'tags': instance.tags,
      'is_featured': instance.isFeatured,
      'created_at': instance.createdAt.toIso8601String(),
      'key_verses': instance.keyVerses,
      'english_title': instance.englishTitle,
      'english_description': instance.englishDescription,
      'english_category': instance.englishCategory,
    };

RecommendedGuideTopicsResponse _$RecommendedGuideTopicsResponseFromJson(
        Map<String, dynamic> json) =>
    RecommendedGuideTopicsResponse(
      topics: (json['topics'] as List<dynamic>)
          .map((e) =>
              RecommendedGuideTopicModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalAvailable: (json['totalAvailable'] as num?)?.toInt(),
      page: (json['page'] as num?)?.toInt(),
      totalPages: (json['totalPages'] as num?)?.toInt(),
    );

Map<String, dynamic> _$RecommendedGuideTopicsResponseToJson(
        RecommendedGuideTopicsResponse instance) =>
    <String, dynamic>{
      'topics': instance.topics,
      'total': instance.total,
      'totalAvailable': instance.totalAvailable,
      'page': instance.page,
      'totalPages': instance.totalPages,
    };
