// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_guide_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SavedGuideModelAdapter extends TypeAdapter<SavedGuideModel> {
  @override
  final int typeId = 1;

  @override
  SavedGuideModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedGuideModel(
      id: fields[0] as String,
      title: fields[1] as String,
      content: fields[2] as String,
      typeString: fields[3] as String,
      createdAt: fields[4] as DateTime,
      lastAccessedAt: fields[5] as DateTime,
      isSaved: fields[6] as bool,
      verseReference: fields[7] as String?,
      topicName: fields[8] as String?,
      summary: fields[9] as String?,
      interpretation: fields[10] as String?,
      context: fields[11] as String?,
      relatedVerses: (fields[12] as List?)?.cast<String>(),
      reflectionQuestions: (fields[13] as List?)?.cast<String>(),
      prayerPoints: (fields[14] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, SavedGuideModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(9)
      ..write(obj.summary)
      ..writeByte(10)
      ..write(obj.interpretation)
      ..writeByte(11)
      ..write(obj.context)
      ..writeByte(12)
      ..write(obj.relatedVerses)
      ..writeByte(13)
      ..write(obj.reflectionQuestions)
      ..writeByte(14)
      ..write(obj.prayerPoints)
      ..writeByte(3)
      ..write(obj.typeString)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.lastAccessedAt)
      ..writeByte(6)
      ..write(obj.isSaved)
      ..writeByte(7)
      ..write(obj.verseReference)
      ..writeByte(8)
      ..write(obj.topicName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedGuideModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

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
      'type': instance.typeString,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastAccessedAt': instance.lastAccessedAt.toIso8601String(),
      'isSaved': instance.isSaved,
      'verseReference': instance.verseReference,
      'topicName': instance.topicName,
    };
