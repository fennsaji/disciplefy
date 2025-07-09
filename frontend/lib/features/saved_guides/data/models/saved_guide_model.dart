import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/saved_guide_entity.dart';

part 'saved_guide_model.g.dart';

@HiveType(typeId: 1)
@JsonSerializable()
class SavedGuideModel extends SavedGuideEntity {
  @HiveField(0)
  @override
  final String id;

  @HiveField(1)
  @override
  final String title;

  @HiveField(2)
  @override
  final String content;

  @HiveField(3)
  @JsonKey(name: 'type')
  final String typeString;

  @HiveField(4)
  @override
  final DateTime createdAt;

  @HiveField(5)
  @override
  final DateTime lastAccessedAt;

  @HiveField(6)
  @override
  final bool isSaved;

  @HiveField(7)
  @override
  final String? verseReference;

  @HiveField(8)
  @override
  final String? topicName;

  const SavedGuideModel({
    required this.id,
    required this.title,
    required this.content,
    required this.typeString,
    required this.createdAt,
    required this.lastAccessedAt,
    required this.isSaved,
    this.verseReference,
    this.topicName,
  }) : super(
          id: id,
          title: title,
          content: content,
          type: typeString == 'verse' ? GuideType.verse : GuideType.topic,
          createdAt: createdAt,
          lastAccessedAt: lastAccessedAt,
          isSaved: isSaved,
          verseReference: verseReference,
          topicName: topicName,
        );

  factory SavedGuideModel.fromJson(Map<String, dynamic> json) =>
      _$SavedGuideModelFromJson(json);

  Map<String, dynamic> toJson() => _$SavedGuideModelToJson(this);

  factory SavedGuideModel.fromEntity(SavedGuideEntity entity) {
    return SavedGuideModel(
      id: entity.id,
      title: entity.title,
      content: entity.content,
      typeString: entity.type == GuideType.verse ? 'verse' : 'topic',
      createdAt: entity.createdAt,
      lastAccessedAt: entity.lastAccessedAt,
      isSaved: entity.isSaved,
      verseReference: entity.verseReference,
      topicName: entity.topicName,
    );
  }

  SavedGuideEntity toEntity() {
    return SavedGuideEntity(
      id: id,
      title: title,
      content: content,
      type: typeString == 'verse' ? GuideType.verse : GuideType.topic,
      createdAt: createdAt,
      lastAccessedAt: lastAccessedAt,
      isSaved: isSaved,
      verseReference: verseReference,
      topicName: topicName,
    );
  }

  @override
  SavedGuideModel copyWith({
    String? id,
    String? title,
    String? content,
    GuideType? type,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
    bool? isSaved,
    String? verseReference,
    String? topicName,
  }) {
    return SavedGuideModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      typeString: type != null ? (type == GuideType.verse ? 'verse' : 'topic') : typeString,
      createdAt: createdAt ?? this.createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      isSaved: isSaved ?? this.isSaved,
      verseReference: verseReference ?? this.verseReference,
      topicName: topicName ?? this.topicName,
    );
  }
}