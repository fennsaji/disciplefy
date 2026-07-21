import 'package:hive/hive.dart';

import 'package:disciplefy_bible_study/features/saved_guides/data/models/saved_guide_model.dart';

/// Hive type adapter for [SavedGuideModel].
///
/// Hand-written (previously produced by `hive_generator`, which is unmaintained
/// and pins `analyzer <7.0.0`). The binary layout below is byte-compatible with
/// the generated version — existing boxes keep reading correctly.
///
/// When adding a field to [SavedGuideModel]:
///  1. Give it the next unused field index (highest so far is 24).
///  2. Read it in [read] via `fields[<index>]`, making it nullable so older
///     records that lack the field still decode.
///  3. Write it in [write] and bump the `writeByte(...)` field count.
/// Never reuse or renumber an existing index, and never change `typeId`.
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
      studyMode: fields[23] as String?,
      verseReference: fields[7] as String?,
      topicName: fields[8] as String?,
      summary: fields[9] as String?,
      interpretation: fields[10] as String?,
      context: fields[11] as String?,
      relatedVerses: (fields[12] as List?)?.cast<String>(),
      reflectionQuestions: (fields[13] as List?)?.cast<String>(),
      prayerPoints: (fields[14] as List?)?.cast<String>(),
      passage: fields[24] as String?,
      interpretationInsights: (fields[15] as List?)?.cast<String>(),
      summaryInsights: (fields[21] as List?)?.cast<String>(),
      reflectionAnswers: (fields[22] as List?)?.cast<String>(),
      contextQuestion: fields[16] as String?,
      summaryQuestion: fields[17] as String?,
      relatedVersesQuestion: fields[18] as String?,
      reflectionQuestion: fields[19] as String?,
      prayerQuestion: fields[20] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SavedGuideModel obj) {
    writer
      ..writeByte(25)
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
      ..writeByte(15)
      ..write(obj.interpretationInsights)
      ..writeByte(16)
      ..write(obj.contextQuestion)
      ..writeByte(17)
      ..write(obj.summaryQuestion)
      ..writeByte(18)
      ..write(obj.relatedVersesQuestion)
      ..writeByte(19)
      ..write(obj.reflectionQuestion)
      ..writeByte(20)
      ..write(obj.prayerQuestion)
      ..writeByte(21)
      ..write(obj.summaryInsights)
      ..writeByte(22)
      ..write(obj.reflectionAnswers)
      ..writeByte(23)
      ..write(obj.studyMode)
      ..writeByte(24)
      ..write(obj.passage)
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
