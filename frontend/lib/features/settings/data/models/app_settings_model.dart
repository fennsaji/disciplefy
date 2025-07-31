import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/app_settings_entity.dart';
import '../../domain/entities/theme_mode_entity.dart';
import 'theme_mode_model.dart';

part 'app_settings_model.g.dart';

@JsonSerializable()
class AppSettingsModel extends AppSettingsEntity {
  @JsonKey(fromJson: ThemeModeModel.fromJson, toJson: _themeModeToJson)
  @override
  final ThemeModeModel themeMode;

  const AppSettingsModel({
    required this.themeMode,
    required super.language,
    required super.notificationsEnabled,
    required super.appVersion,
  }) : super(themeMode: themeMode);

  static Map<String, dynamic> _themeModeToJson(ThemeModeEntity themeMode) => ThemeModeModel.fromEntity(themeMode).toJson();

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsModelFromJson(json);

  Map<String, dynamic> toJson() => _$AppSettingsModelToJson(this);

  factory AppSettingsModel.fromEntity(AppSettingsEntity entity) => AppSettingsModel(
      themeMode: ThemeModeModel.fromEntity(entity.themeMode),
      language: entity.language,
      notificationsEnabled: entity.notificationsEnabled,
      appVersion: entity.appVersion,
    );

  factory AppSettingsModel.defaultSettings() => AppSettingsModel(
      themeMode: ThemeModeModel.fromEntity(ThemeModeEntity.light()),
      language: 'en',
      notificationsEnabled: true,
      appVersion: '', // Will be populated dynamically from PackageInfo
    );

  @override
  AppSettingsModel copyWith({
    ThemeModeEntity? themeMode,
    String? language,
    bool? notificationsEnabled,
    String? appVersion,
  }) => AppSettingsModel(
      themeMode: themeMode != null ? ThemeModeModel.fromEntity(themeMode) : this.themeMode,
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      appVersion: appVersion ?? this.appVersion,
    );
}