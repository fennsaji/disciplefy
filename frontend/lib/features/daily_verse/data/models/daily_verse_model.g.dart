// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_verse_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DailyVerseModel _$DailyVerseModelFromJson(Map<String, dynamic> json) =>
    DailyVerseModel(
      reference: json['reference'] as String,
      translations: DailyVerseTranslationsModel.fromJson(
          json['translations'] as Map<String, dynamic>),
      date: json['date'] as String,
    );

Map<String, dynamic> _$DailyVerseModelToJson(DailyVerseModel instance) =>
    <String, dynamic>{
      'reference': instance.reference,
      'translations': instance.translations,
      'date': instance.date,
    };

DailyVerseTranslationsModel _$DailyVerseTranslationsModelFromJson(
        Map<String, dynamic> json) =>
    DailyVerseTranslationsModel(
      esv: json['esv'] as String,
      hi: json['hi'] as String,
      ml: json['ml'] as String,
    );

Map<String, dynamic> _$DailyVerseTranslationsModelToJson(
        DailyVerseTranslationsModel instance) =>
    <String, dynamic>{
      'esv': instance.esv,
      'hi': instance.hi,
      'ml': instance.ml,
    };

DailyVerseResponse _$DailyVerseResponseFromJson(Map<String, dynamic> json) =>
    DailyVerseResponse(
      success: json['success'] as bool,
      data: DailyVerseModel.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DailyVerseResponseToJson(DailyVerseResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'data': instance.data,
    };