import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/daily_verse_entity.dart';

part 'daily_verse_model.g.dart';

/// Data model for daily verse API responses
@JsonSerializable()
class DailyVerseModel {
  final String?
      id; // UUID from daily_verses_cache table (nullable for newly generated verses)
  final String reference;
  final ReferenceTranslationsModel referenceTranslations;
  final DailyVerseTranslationsModel translations;
  final String date;

  const DailyVerseModel({
    this.id, // Optional - only present for cached verses
    required this.reference,
    required this.referenceTranslations,
    required this.translations,
    required this.date,
  });

  factory DailyVerseModel.fromJson(Map<String, dynamic> json) =>
      _$DailyVerseModelFromJson(json);

  Map<String, dynamic> toJson() => _$DailyVerseModelToJson(this);

  /// Convert to domain entity
  DailyVerseEntity toEntity() => DailyVerseEntity(
        id: id ??
            'temp-$date', // Use date-based temp ID for newly generated verses
        reference: reference,
        referenceTranslations: referenceTranslations.toEntity(),
        translations: translations.toEntity(),
        date: DateTime.parse(date),
      );
}

@JsonSerializable()
class ReferenceTranslationsModel {
  final String en;
  final String hi;
  final String ml;

  const ReferenceTranslationsModel({
    required this.en,
    required this.hi,
    required this.ml,
  });

  factory ReferenceTranslationsModel.fromJson(Map<String, dynamic> json) =>
      _$ReferenceTranslationsModelFromJson(json);

  Map<String, dynamic> toJson() => _$ReferenceTranslationsModelToJson(this);

  /// Convert to domain entity
  ReferenceTranslations toEntity() => ReferenceTranslations(
        en: en,
        hi: hi,
        ml: ml,
      );
}

@JsonSerializable()
class DailyVerseTranslationsModel {
  final String? esv;
  final String? hindi;
  final String? malayalam;

  const DailyVerseTranslationsModel({
    this.esv,
    this.hindi,
    this.malayalam,
  });

  factory DailyVerseTranslationsModel.fromJson(Map<String, dynamic> json) =>
      _$DailyVerseTranslationsModelFromJson(json);

  Map<String, dynamic> toJson() => _$DailyVerseTranslationsModelToJson(this);

  /// Convert to domain entity
  DailyVerseTranslations toEntity() => DailyVerseTranslations(
        esv: esv ?? '',
        hindi: hindi ?? '',
        malayalam: malayalam ?? '',
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
