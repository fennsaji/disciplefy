import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/daily_verse_entity.dart';

part 'daily_verse_model.g.dart';

/// Data model for daily verse API responses
@JsonSerializable()
class DailyVerseModel {
  final String reference;
  final DailyVerseTranslationsModel translations;
  final String date;

  const DailyVerseModel({
    required this.reference,
    required this.translations,
    required this.date,
  });

  factory DailyVerseModel.fromJson(Map<String, dynamic> json) =>
      _$DailyVerseModelFromJson(json);

  Map<String, dynamic> toJson() => _$DailyVerseModelToJson(this);

  /// Convert to domain entity
  DailyVerseEntity toEntity() => DailyVerseEntity(
      reference: reference,
      translations: translations.toEntity(),
      date: DateTime.parse(date),
    );
}

@JsonSerializable()
class DailyVerseTranslationsModel {
  final String esv;
  final String hi;
  final String ml;

  const DailyVerseTranslationsModel({
    required this.esv,
    required this.hi,
    required this.ml,
  });

  factory DailyVerseTranslationsModel.fromJson(Map<String, dynamic> json) =>
      _$DailyVerseTranslationsModelFromJson(json);

  Map<String, dynamic> toJson() => _$DailyVerseTranslationsModelToJson(this);

  /// Convert to domain entity
  DailyVerseTranslations toEntity() => DailyVerseTranslations(
      esv: esv,
      hindi: hi,
      malayalam: ml,
    );
}

@JsonSerializable()
class DailyVerseResponse {
  final bool success;
  final DailyVerseModel data;

  const DailyVerseResponse({
    required this.success,
    required this.data,
  });

  factory DailyVerseResponse.fromJson(Map<String, dynamic> json) =>
      _$DailyVerseResponseFromJson(json);

  Map<String, dynamic> toJson() => _$DailyVerseResponseToJson(this);
}