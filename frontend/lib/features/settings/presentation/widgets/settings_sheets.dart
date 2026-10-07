import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/constants/study_mode_preferences.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/apple_consumable_purchase_service.dart';
import 'package:disciplefy_bible_study/core/services/auth_state_provider.dart';
import 'package:disciplefy_bible_study/core/services/font_scale_service.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/settings/domain/entities/theme_mode_entity.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/bloc/settings_event.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheet.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/user_profile/data/models/user_profile_model.dart';
import 'package:disciplefy_bible_study/features/user_profile/data/services/user_profile_service.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';
import 'package:disciplefy_bible_study/shared/widgets/content_language_sheet.dart';

// ---------------------------------------------------------------------------
// Labels shared by the Settings rows and their sheets
// ---------------------------------------------------------------------------

/// Short theme name, the same on the Settings row and the theme sheet.
String themeModeLabel(BuildContext context, AppThemeMode mode) =>
    switch (mode) {
      AppThemeMode.light => context.tr(TranslationKeys.settingsThemeLight),
      AppThemeMode.dark => context.tr(TranslationKeys.settingsThemeDark),
      AppThemeMode.system => context.tr(TranslationKeys.settingsThemeSystem),
    };

String fontScaleLevelLabel(BuildContext context, FontScaleLevel level) =>
    switch (level) {
      FontScaleLevel.small => context.tr(TranslationKeys.settingsTextSizeSmall),
      FontScaleLevel.normal =>
        context.tr(TranslationKeys.settingsTextSizeNormal),
      FontScaleLevel.large => context.tr(TranslationKeys.settingsTextSizeLarge),
      FontScaleLevel.extraLarge =>
        context.tr(TranslationKeys.settingsTextSizeExtraLarge),
    };

String studyModeName(BuildContext context, StudyMode mode) => switch (mode) {
      StudyMode.quick => context.tr(TranslationKeys.studyModeQuickName),
      StudyMode.standard => context.tr(TranslationKeys.studyModeStandardName),
      StudyMode.deep => context.tr(TranslationKeys.studyModeDeepName),
      StudyMode.lectio => context.tr(TranslationKeys.studyModeLectioName),
      StudyMode.sermon => context.tr(TranslationKeys.studyModeSermonName),
    };

String studyModeDescription(BuildContext context, StudyMode mode) =>
    switch (mode) {
      StudyMode.quick => context.tr(TranslationKeys.studyModeQuickDescription),
      StudyMode.standard =>
        context.tr(TranslationKeys.studyModeStandardDescription),
      StudyMode.deep => context.tr(TranslationKeys.studyModeDeepDescription),
      StudyMode.lectio =>
        context.tr(TranslationKeys.studyModeLectioDescription),
      StudyMode.sermon =>
        context.tr(TranslationKeys.studyModeSermonDescription),
    };

/// Display name for a stored study-mode value; unknown values read as
/// Standard.
String studyModeNameForValue(BuildContext context, String value) {
  final mode = StudyMode.values.firstWhere(
    (m) => m.value == value,
    orElse: () => StudyMode.standard,
  );
  return studyModeName(context, mode);
}

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------

/// Theme picker: three preview tiles (System, Light, Dark).
void showThemeSheet(BuildContext context, ThemeModeEntity currentTheme) {
  Logger.debug(
      'Opening theme bottom sheet - Current theme: ${currentTheme.mode}');
  final settingsBloc = BlocProvider.of<SettingsBloc>(context);

  showSettingsSheet<void>(
    context: context,
    builder: (sheetContext) {
      void pick(ThemeModeEntity option) {
        Logger.debug('Theme option selected: ${option.mode}');
        settingsBloc.add(ThemeModeChanged(option));
        Navigator.of(sheetContext).pop();
      }

      final options = <ThemeModeEntity>[
        // Match the current system state so the selection is right.
        ThemeModeEntity.system(isDarkMode: currentTheme.isDarkMode),
        ThemeModeEntity.light(),
        ThemeModeEntity.dark(),
      ];
      final palette = ReaderPalette.of(sheetContext);

      return SettingsSheetFrame(
        title: sheetContext.tr(TranslationKeys.settingsTheme),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: ThemePreviewOption(
                    mode: options[i].mode,
                    label: themeModeLabel(sheetContext, options[i].mode),
                    description:
                        themeModeDescription(sheetContext, options[i].mode),
                    selected: options[i].mode == currentTheme.mode,
                    onTap: () => pick(options[i]),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            sheetContext.tr(TranslationKeys.settingsThemeSystemCaption),
            textAlign: TextAlign.center,
            style: AppFonts.inter(
              fontSize: 13,
              color: palette.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
        ],
      );
    },
  );
}

/// One line on what each theme option does ("Follows your device theme").
String themeModeDescription(BuildContext context, AppThemeMode mode) =>
    switch (mode) {
      AppThemeMode.light =>
        context.tr(TranslationKeys.settingsLightModeSubtitle),
      AppThemeMode.dark => context.tr(TranslationKeys.settingsDarkModeSubtitle),
      AppThemeMode.system =>
        context.tr(TranslationKeys.settingsSystemDefaultSubtitle),
    };

/// A miniature screen preview with its caption and a short description;
/// System is split light/dark.
class ThemePreviewOption extends StatelessWidget {
  final AppThemeMode mode;
  final String label;
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  const ThemePreviewOption({
    super.key,
    required this.mode,
    required this.label,
    required this.selected,
    required this.onTap,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final preview = switch (mode) {
      AppThemeMode.light => const _MiniScreen(dark: false),
      AppThemeMode.dark => const _MiniScreen(dark: true),
      AppThemeMode.system => const Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
                clipper: _HalfClipper(left: true),
                child: _MiniScreen(dark: false)),
            ClipRect(
                clipper: _HalfClipper(left: false),
                child: _MiniScreen(dark: true)),
          ],
        ),
    };

    return Semantics(
      button: true,
      selected: selected,
      label: description == null ? label : '$label. $description',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 0.79,
              child: Container(
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? settingsPrimaryFill : palette.outline,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: preview,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? palette.text : palette.muted,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 2),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: AppFonts.inter(
                  fontSize: 12,
                  color: palette.muted,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HalfClipper extends CustomClipper<Rect> {
  final bool left;

  const _HalfClipper({required this.left});

  @override
  Rect getClip(Size size) => left
      ? Rect.fromLTWH(0, 0, size.width / 2, size.height)
      : Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height);

  @override
  bool shouldReclip(covariant _HalfClipper oldClipper) =>
      oldClipper.left != left;
}

/// Page, title line, indigo button and a neutral card.
class _MiniScreen extends StatelessWidget {
  final bool dark;

  const _MiniScreen({required this.dark});

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF0B0B0B) : const Color(0xFFF4F4F6);
    final line = dark ? const Color(0xFF3A3A3A) : const Color(0xFFC9C9CF);
    final card = dark ? const Color(0xFF262626) : const Color(0xFFE4E4E7);
    return ColoredBox(
      color: bg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final pad = w * 0.11;
          return Padding(
            padding: EdgeInsets.fromLTRB(pad, w * 0.16, pad, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: w * 0.45,
                  height: w * 0.07,
                  decoration: BoxDecoration(
                    color: line,
                    borderRadius: BorderRadius.circular(w),
                  ),
                ),
                SizedBox(height: w * 0.07),
                Container(
                  height: w * 0.27,
                  decoration: BoxDecoration(
                    color: settingsPrimaryFill,
                    borderRadius: BorderRadius.circular(w * 0.08),
                  ),
                ),
                SizedBox(height: w * 0.09),
                Container(
                  height: w * 0.22,
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(w * 0.08),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// App language
// ---------------------------------------------------------------------------

/// App-language picker: native name with the English name under it.
void showAppLanguageSheet(BuildContext context, String currentLanguage) {
  final settingsBloc = BlocProvider.of<SettingsBloc>(context);

  showSettingsSheet<void>(
    context: context,
    builder: (sheetContext) {
      final palette = ReaderPalette.of(sheetContext);
      return SettingsSheetFrame(
        title: sheetContext.tr(TranslationKeys.settingsAppLanguage),
        children: [
          SettingsSheetGroup(
            children: [
              for (final language in AppLanguage.values)
                LanguageOptionTile(
                  label: language.displayName,
                  subtitle: languageEnglishName(sheetContext, language),
                  isSelected: language.code == currentLanguage,
                  onTap: () {
                    settingsBloc.add(UpdateLanguage(language.code));
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              sheetContext.tr(TranslationKeys.settingsAppLanguageDescription),
              style: AppFonts.inter(
                fontSize: 13,
                color: palette.muted,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Text size
// ---------------------------------------------------------------------------

void showTextSizeSheet(BuildContext context) {
  final fontScaleService = sl<FontScaleService>();

  showSettingsSheet<void>(
    context: context,
    builder: (builderContext) => StatefulBuilder(
      builder: (sheetContext, setState) {
        final palette = ReaderPalette.of(sheetContext);
        return SettingsSheetFrame(
          title: sheetContext.tr(TranslationKeys.settingsTextSize),
          description:
              sheetContext.tr(TranslationKeys.settingsTextSizeSubtitle),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.raised,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListenableBuilder(
                listenable: fontScaleService,
                builder: (ctx, _) => Text(
                  'For God so loved the world... (John 3:16)',
                  style: AppFonts.inter(
                    fontSize: 15 * fontScaleService.scaleFactor,
                    fontStyle: FontStyle.italic,
                    color: palette.text,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SettingsSheetGroup(
              children: [
                for (final level in FontScaleLevel.values)
                  SettingsRadioRow(
                    title: fontScaleLevelLabel(sheetContext, level),
                    subtitle: sheetContext.tr(
                        TranslationKeys.settingsTextSizePercentage, {
                      'percent': (level.scaleFactor * 100).round().toString()
                    }),
                    selected: fontScaleService.level == level,
                    onTap: () async {
                      await fontScaleService.updateScale(level);
                      setState(() {});
                    },
                  ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Study mode preferences
// ---------------------------------------------------------------------------

/// Default study mode for generated guides. Saves to the profile, then the
/// local cache, then closes.
void showStudyModeSheet(BuildContext context, String? currentMode) {
  final parentContext = context;

  showSettingsSheet<void>(
    context: context,
    builder: (sheetContext) {
      Future<void> choose(String? value, String label) async {
        try {
          final userProfileService = sl<UserProfileService>();
          final authProvider = sl<AuthStateProvider>();
          final languageService = sl<LanguagePreferenceService>();

          final result =
              await userProfileService.updateStudyModePreference(value);

          if (parentContext.mounted) {
            result.fold(
              (failure) {
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                showSettingsSnackBar(
                  parentContext,
                  parentContext.tr(TranslationKeys.commonErrorTryAgain),
                  Theme.of(parentContext).colorScheme.error,
                );
              },
              (profile) async {
                // Update the auth provider cache with the new profile.
                if (authProvider.userId != null) {
                  final profileMap =
                      UserProfileModel.fromEntity(profile).toJson();
                  authProvider.cacheProfile(authProvider.userId!, profileMap);
                }

                // Sync local storage (save, or clear for "Ask every time").
                if (value != null) {
                  await languageService.saveStudyModePreferenceRaw(value);
                } else {
                  await languageService.clearStudyModePreference();
                }

                // Close the sheet after the cache is updated.
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();

                showSettingsSnackBar(
                  parentContext,
                  value == null
                      ? 'Study mode preference cleared'
                      : 'Default study mode set to $label',
                  AppColors.success,
                );
              },
            );
          }
        } catch (e) {
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          if (parentContext.mounted) {
            showSettingsSnackBar(
              parentContext,
              'Failed to update study mode preference: $e',
              Theme.of(parentContext).colorScheme.error,
            );
          }
        }
      }

      return _StudyModeSheetBody(
        title: sheetContext.tr(TranslationKeys.settingsStudyModePreference),
        description: sheetContext.tr(TranslationKeys.modeSelectionSubtitle),
        currentMode: currentMode,
        askEveryTimeValue: null,
        onChoose: choose,
      );
    },
  );
}

/// Study mode used for learning path topics.
void showLearningPathStudyModeSheet(BuildContext context, String? currentMode) {
  final parentContext = context;

  showSettingsSheet<void>(
    context: context,
    builder: (sheetContext) {
      Future<void> choose(String? value, String label) async {
        // Learning paths always store a value ("Ask" has its own value).
        final mode = value ?? StudyModePreferences.learningPathDefault;
        try {
          final userProfileService = sl<UserProfileService>();
          final authProvider = sl<AuthStateProvider>();

          final result = await userProfileService
              .updateLearningPathStudyModePreference(mode);

          if (parentContext.mounted) {
            result.fold(
              (failure) {
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                showSettingsSnackBar(
                  parentContext,
                  parentContext.tr(TranslationKeys.errorUpdatingPreference),
                  Theme.of(parentContext).colorScheme.error,
                );
              },
              (profile) {
                final userId = authProvider.userId;
                if (userId != null) {
                  final profileMap =
                      UserProfileModel.fromEntity(profile).toJson();
                  authProvider.cacheProfile(userId, profileMap);
                }
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                showSettingsSnackBar(
                  parentContext,
                  parentContext
                      .tr(TranslationKeys.preferenceUpdatedSuccessfully),
                  AppColors.success,
                );
              },
            );
          }
        } catch (e) {
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          if (parentContext.mounted) {
            showSettingsSnackBar(
              parentContext,
              parentContext.tr(TranslationKeys.errorUpdatingPreference),
              Theme.of(parentContext).colorScheme.error,
            );
          }
        }
      }

      return _StudyModeSheetBody(
        title: sheetContext
            .tr(TranslationKeys.settingsLearningPathStudyModePreference),
        description: sheetContext
            .tr(TranslationKeys.settingsLearningPathStudyModeDescription),
        currentMode: currentMode,
        askEveryTimeValue: StudyModePreferences.learningPathDefault,
        onChoose: choose,
      );
    },
  );
}

/// Recommended / Ask every time, then one row per study mode.
class _StudyModeSheetBody extends StatelessWidget {
  final String title;
  final String description;
  final String? currentMode;

  /// Stored value meaning "ask every time" (null for general studies).
  final String? askEveryTimeValue;
  final Future<void> Function(String? value, String label) onChoose;

  const _StudyModeSheetBody({
    required this.title,
    required this.description,
    required this.currentMode,
    required this.askEveryTimeValue,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    final recommended = context.tr(TranslationKeys.settingsUseRecommended);
    final ask = context.tr(TranslationKeys.settingsAskEveryTime);
    return SettingsSheetFrame(
      title: title,
      description: description,
      children: [
        SettingsSheetGroup(
          children: [
            SettingsRadioRow(
              icon: Icons.stars_outlined,
              tone: SettingsTone.gold,
              title: recommended,
              subtitle:
                  context.tr(TranslationKeys.settingsUseRecommendedSubtitle),
              selected: currentMode == StudyModePreferences.recommended,
              onTap: () =>
                  onChoose(StudyModePreferences.recommended, recommended),
            ),
            SettingsRadioRow(
              icon: Icons.help_outline,
              title: ask,
              subtitle:
                  context.tr(TranslationKeys.settingsAskEveryTimeSubtitle),
              selected: currentMode == askEveryTimeValue,
              onTap: () => onChoose(askEveryTimeValue, ask),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsSheetGroup(
          children: [
            for (final mode in StudyMode.values)
              SettingsRadioRow(
                icon: mode.iconData,
                title: studyModeName(context, mode),
                subtitle:
                    '${mode.durationText} • ${studyModeDescription(context, mode)}',
                selected: currentMode == mode.value,
                onTap: () => onChoose(mode.value, studyModeName(context, mode)),
              ),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Contact / support / tips
// ---------------------------------------------------------------------------

/// Email, Instagram and Facebook. Launches use [context] (the page), since
/// the sheet's context is gone once it pops.
void showContactSheet(BuildContext context) {
  Future<void> launch(Uri uri, {bool external = false}) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: external
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      );
    } else if (context.mounted) {
      showSettingsSnackBar(
        context,
        context.tr(TranslationKeys.settingsContactError),
        Colors.red,
      );
    }
  }

  showSettingsSheet<void>(
    context: context,
    builder: (sheetContext) {
      void open(Uri uri, {bool external = false}) {
        Navigator.of(sheetContext).pop();
        launch(uri, external: external);
      }

      return SettingsSheetFrame(
        title: sheetContext.tr(TranslationKeys.settingsContactUs),
        children: [
          SettingsSheetGroup(
            children: [
              SettingsRow(
                icon: Icons.email_outlined,
                tone: SettingsTone.sky,
                title: sheetContext.tr(TranslationKeys.settingsContactEmail),
                subtitle: 'contact@disciplefy.in',
                onTap: () => open(Uri.parse(
                    'mailto:contact@disciplefy.in?subject=Disciplefy Support Request')),
              ),
              SettingsRow(
                icon: Icons.camera_alt_outlined,
                tone: SettingsTone.pink,
                title: 'Instagram',
                subtitle: '@disciplefy.in',
                onTap: () => open(
                    Uri.parse('https://www.instagram.com/disciplefy.in'),
                    external: true),
              ),
              SettingsRow(
                icon: Icons.facebook,
                title: 'Facebook',
                subtitle: 'facebook.com/disciplefy',
                onTap: () => open(
                    Uri.parse('https://www.facebook.com/disciplefy'),
                    external: true),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      );
    },
  );
}

/// Android/web: support message with a Buy Me a Coffee link.
void showSupportSheet(BuildContext context) {
  Future<void> launchBuyMeCoffee() async {
    final uri = Uri.parse('https://buymeacoffee.com/fennsaji');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  showSettingsSheet<void>(
    context: context,
    builder: (sheetContext) {
      final palette = ReaderPalette.of(sheetContext);
      return SettingsSheetFrame(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SettingsIconTile(
            icon: Icons.favorite_outline,
            tone: SettingsTone.pink,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            sheetContext.tr(TranslationKeys.settingsSupportTitle),
            textAlign: TextAlign.center,
            style: AppFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            sheetContext.tr(TranslationKeys.settingsSupportMessage),
            textAlign: TextAlign.center,
            style: AppFonts.inter(
              fontSize: 14.5,
              color: palette.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SettingsButtonRow(
            buttons: [
              SettingsButton(
                label: sheetContext.tr(TranslationKeys.settingsClose),
                kind: SettingsButtonKind.neutral,
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
              SettingsButton(
                label: sheetContext.tr(TranslationKeys.settingsSupport),
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  launchBuyMeCoffee();
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      );
    },
  );
}

/// iOS tip jar: one-time consumable In-App Purchases (guideline 3.1.1).
void showTipSheet(BuildContext context) {
  final service = sl<AppleConsumablePurchaseService>();
  service.bind();

  // Load products once — creating the future inside the FutureBuilder's build
  // would re-query the store on every rebuild (e.g. when the sheet scrolls).
  final tipProductsFuture = service.loadTipProducts();

  // Full-screen loader shown between tapping a tip and the StoreKit payment
  // sheet appearing / backend confirmation completing.
  bool loaderOpen = false;
  void showLoader() {
    if (loaderOpen || !context.mounted) return;
    loaderOpen = true;
    showSettingsLoader(context);
  }

  void dismissLoader() {
    if (!loaderOpen || !context.mounted) return;
    loaderOpen = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  // Only react to the tip the user actively bought (loader was open). These
  // callbacks also fire for background sandbox replays — ignore those so we
  // don't show a stray "thanks"/error or pop an unrelated route.
  service.onSuccess = (result) {
    final wasInFlight = loaderOpen;
    dismissLoader();
    if (!wasInFlight || result.kind != ConsumableKind.tip || !context.mounted) {
      return;
    }
    showAppSnackBar(
      context,
      context.tr(TranslationKeys.settingsTipThanks),
      tone: AppSnackTone.success,
    );
  };
  service.onError = (message) {
    final wasInFlight = loaderOpen;
    dismissLoader();
    if (!wasInFlight || !context.mounted) return;
    showSettingsSnackBar(context, message, Colors.red);
  };
  service.onCancelled = () {
    final wasInFlight = loaderOpen;
    dismissLoader();
    if (!wasInFlight || !context.mounted) return;
    showAppSnackBar(
      context,
      context.tr(TranslationKeys.commonPurchaseCancelled),
    );
  };

  const tipEmojis = {49: '☕', 199: '🙌', 499: '💛', 999: '🌟'};

  showSettingsSheet<void>(
    context: context,
    builder: (builderContext) {
      final palette = ReaderPalette.of(builderContext);
      return SettingsSheetFrame(
        title: builderContext.tr(TranslationKeys.settingsSupportTitle),
        description: builderContext.tr(TranslationKeys.settingsSupportMessage),
        children: [
          FutureBuilder<Map<int, ProductDetails>>(
            future: tipProductsFuture,
            builder: (sheetContext, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return SizedBox(
                  height: 160,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: ReaderPalette.of(sheetContext).gold,
                    ),
                  ),
                );
              }
              final products = snapshot.data ?? {};
              final amounts = products.keys.toList()..sort();

              if (amounts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    sheetContext.tr(TranslationKeys.settingsTipUnavailable),
                    style: AppFonts.inter(fontSize: 14, color: palette.muted),
                  ),
                );
              }
              return SettingsSheetGroup(
                children: [
                  for (final amount in amounts)
                    _TipRow(
                      emoji: tipEmojis[amount] ?? '💝',
                      title: products[amount]!.title.isNotEmpty
                          ? products[amount]!.title
                          : sheetContext.tr(TranslationKeys.settingsSupport),
                      price: products[amount]!.price,
                      onTap: () {
                        Navigator.of(builderContext).pop();
                        showLoader();
                        service.purchase(products[amount]!);
                      },
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
        ],
      );
    },
  );
}

class _TipRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String price;
  final VoidCallback onTap;

  const _TipRow({
    required this.emoji,
    required this.title,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: AppFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: palette.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              price,
              style: AppFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: palette.accentIcon,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
