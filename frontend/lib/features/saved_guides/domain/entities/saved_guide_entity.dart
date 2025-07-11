import 'package:equatable/equatable.dart';

enum GuideType {
  verse,
  topic,
}

class SavedGuideEntity extends Equatable {
  final String id;
  final String title;
  final String content;
  final GuideType type;
  final DateTime createdAt;
  final DateTime lastAccessedAt;
  final bool isSaved;
  final String? verseReference;
  final String? topicName;

  const SavedGuideEntity({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.lastAccessedAt,
    required this.isSaved,
    this.verseReference,
    this.topicName,
  });

  SavedGuideEntity copyWith({
    String? id,
    String? title,
    String? content,
    GuideType? type,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
    bool? isSaved,
    String? verseReference,
    String? topicName,
  }) => SavedGuideEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      isSaved: isSaved ?? this.isSaved,
      verseReference: verseReference ?? this.verseReference,
      topicName: topicName ?? this.topicName,
    );

  String get displayTitle {
    switch (type) {
      case GuideType.verse:
        return verseReference ?? title;
      case GuideType.topic:
        return topicName ?? title;
    }
  }

  String get subtitle {
    switch (type) {
      case GuideType.verse:
        return 'Bible Verse Study';
      case GuideType.topic:
        return 'Topic Study';
    }
  }

  @override
  List<Object?> get props => [
        id,
        title,
        content,
        type,
        createdAt,
        lastAccessedAt,
        isSaved,
        verseReference,
        topicName,
      ];
}