import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:disciplefy_bible_study/core/constants/legal_urls.dart';
import 'package:disciplefy_bible_study/core/constants/study_mode_preferences.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/auth_state_provider.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/platform_utils.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/feedback/presentation/widgets/feedback_bottom_sheet.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_bloc.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_event.dart';
import 'package:disciplefy_bible_study/features/onboarding/domain/growth_goals.dart';
import 'package:disciplefy_bible_study/features/personalization/domain/growth_goal_repository.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/bloc/settings_state.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheet.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheets.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

/// True for an anonymous (guest) user. False when the service is missing.
bool isGuestUser() {
  try {
    return sl.isRegistered<GuestSessionService>() &&
        sl<GuestSessionService>().isGuest;
  } catch (_) {
    return false;
  }
}

/// The less-used Settings rows, one tap from the main list: study
/// preferences, help and about (support, attribution, policies, version).
class SettingsMorePage extends StatefulWidget {
  const SettingsMorePage({super.key});

  @override
  State<SettingsMorePage> createState() => _SettingsMorePageState();
}

class _SettingsMorePageState extends State<SettingsMorePage> {
  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: SettingsTopBar(
        title: context.tr(TranslationKeys.settingsMore),
        onBack: _goBack,
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final authProvider = sl<AuthStateProvider>();
          return ListenableBuilder(
            listenable: authProvider,
            builder: (context, _) {
              final isGuest = isGuestUser();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                children: [
                  if (authProvider.isAuthenticated)
                    ..._studySection(context, authProvider),
                  ..._helpSection(context, isGuest: isGuest),
                  ..._aboutSection(
                    context,
                    state is SettingsLoaded ? state.settings.appVersion : null,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Sections
  // -------------------------------------------------------------------------

  List<Widget> _studySection(
      BuildContext context, AuthStateProvider authProvider) {
    final defaultMode =
        authProvider.userProfile?['default_study_mode'] as String?;
    final learningPathMode =
        authProvider.userProfile?['learning_path_study_mode'] as String?;

    final String studyModeSubtitle;
    if (StudyModePreferences.isGeneralAskEveryTime(defaultMode)) {
      studyModeSubtitle = context.tr(TranslationKeys.settingsAskEveryTime);
    } else if (StudyModePreferences.isRecommended(defaultMode)) {
      studyModeSubtitle = context.tr(TranslationKeys.settingsUseRecommended);
    } else {
      studyModeSubtitle = context
          .tr(TranslationKeys.settingsStudyModePreferenceCurrent)
          .replaceAll('{mode}', studyModeNameForValue(context, defaultMode!));
    }

    final String learningPathSubtitle;
    if (StudyModePreferences.isLearningPathAskEveryTime(learningPathMode)) {
      learningPathSubtitle = context.tr(TranslationKeys.settingsAskEveryTime);
    } else if (StudyModePreferences.isRecommended(learningPathMode)) {
      learningPathSubtitle = context.tr(TranslationKeys.settingsUseRecommended);
    } else {
      learningPathSubtitle = context
          .tr(TranslationKeys.settingsStudyModePreferenceCurrent)
          .replaceAll(
              '{mode}', studyModeNameForValue(context, learningPathMode!));
    }

    return [
      SettingsSectionLabel(context.tr(TranslationKeys.settingsSectionStudy)),
      SettingsGroup(
        children: [
          SettingsRow(
            key: const Key('settings_change_goal'),
            icon: Icons.flag_outlined,
            title: context.tr(TranslationKeys.goalSettingsRow),
            subtitle: _goalSubtitle(context),
            onTap: () => _openChangeGoal(context),
          ),
          SettingsRow(
            icon: Icons.school_outlined,
            title: context.tr(TranslationKeys.settingsStudyModePreference),
            subtitle: studyModeSubtitle,
            onTap: () => showStudyModeSheet(context, defaultMode),
          ),
          SettingsRow(
            icon: Icons.route_outlined,
            title: context
                .tr(TranslationKeys.settingsLearningPathStudyModePreference),
            subtitle: learningPathSubtitle,
            onTap: () =>
                showLearningPathStudyModeSheet(context, learningPathMode),
          ),
        ],
      ),
    ];
  }

  List<Widget> _helpSection(BuildContext context, {required bool isGuest}) => [
        SettingsSectionLabel(context.tr(TranslationKeys.settingsHelpSupport)),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.chat_bubble_outline_rounded,
              title: context.tr(TranslationKeys.settingsFeedback),
              subtitle: context.tr(TranslationKeys.settingsFeedbackSubtitle),
              onTap: () => showFeedbackBottomSheet(context),
            ),
            // A guest has no purchases to report.
            if (!isGuest)
              SettingsRow(
                icon: Icons.receipt_long_outlined,
                title: context.tr(TranslationKeys.settingsReportPurchaseIssue),
                subtitle: context
                    .tr(TranslationKeys.settingsReportPurchaseIssueSubtitle),
                onTap: () => context.push(AppRoutes.purchaseHistory),
              ),
            SettingsRow(
              icon: Icons.mail_outline_rounded,
              tone: SettingsTone.sky,
              title: context.tr(TranslationKeys.settingsContactUs),
              subtitle: context.tr(TranslationKeys.settingsContactUsSubtitle),
              onTap: () => showContactSheet(context),
            ),
            SettingsRow(
              icon: Icons.replay_rounded,
              title: context.tr(TranslationKeys.settingsReplayWalkthrough),
              subtitle:
                  context.tr(TranslationKeys.settingsReplayWalkthroughSubtitle),
              onTap: () => _replayWalkthrough(context),
            ),
          ],
        ),
      ];

  List<Widget> _aboutSection(BuildContext context, String? appVersion) => [
        SettingsSectionLabel(context.tr(TranslationKeys.settingsAbout)),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.favorite_outline,
              tone: SettingsTone.pink,
              title: context.tr(TranslationKeys.settingsSupportDeveloper),
              subtitle:
                  context.tr(TranslationKeys.settingsSupportDeveloperSubtitle),
              // iOS: tips must go through In-App Purchase (guideline 3.1.1);
              // Android/web keep the external Buy Me a Coffee link.
              onTap: () => PlatformUtils.isIOS
                  ? showTipSheet(context)
                  : showSupportSheet(context),
            ),
            SettingsRow(
              icon: Icons.book_outlined,
              title: context.tr(TranslationKeys.settingsBibleAttribution),
              subtitle:
                  context.tr(TranslationKeys.settingsBibleAttributionSubtitle),
              onTap: () => context.push(AppRoutes.bibleAttribution),
            ),
            SettingsRow(
              icon: Icons.verified_user_outlined,
              title: context.tr(TranslationKeys.settingsPrivacyPolicy),
              subtitle:
                  context.tr(TranslationKeys.settingsPrivacyPolicySubtitle),
              onTap: () => _launchExternal(LegalUrls.privacy),
            ),
            SettingsRow(
              icon: Icons.description_outlined,
              title: context.tr(TranslationKeys.settingsTermsOfService),
              subtitle:
                  context.tr(TranslationKeys.settingsTermsOfServiceSubtitle),
              onTap: () => _launchExternal(LegalUrls.terms),
            ),
            SettingsRow(
              icon: Icons.receipt_outlined,
              title: context.tr(TranslationKeys.settingsRefundPolicy),
              subtitle:
                  context.tr(TranslationKeys.settingsRefundPolicySubtitle),
              onTap: () => _launchExternal('https://www.disciplefy.in/refund'),
            ),
            SettingsRow(
              icon: Icons.info_outline,
              title: context.tr(TranslationKeys.settingsAppVersion),
              value: appVersion,
            ),
          ],
        ),
      ];

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  /// The saved goal's name, or "Not chosen yet".
  String _goalSubtitle(BuildContext context) {
    GrowthGoal? goal;
    try {
      if (sl.isRegistered<GrowthGoalRepository>()) {
        goal = sl<GrowthGoalRepository>().cachedGoal;
      }
    } catch (_) {
      goal = null;
    }
    return context.tr(goal?.labelKey ?? TranslationKeys.goalNotChosen);
  }

  /// Opens Change my goal; a new goal changes what comes next, so the
  /// suggested paths are reloaded.
  Future<void> _openChangeGoal(BuildContext context) async {
    final changed = await context.push<bool>(AppRoutes.changeGoal);
    if (changed != true) return;
    if (mounted) setState(() {});
    sl<LearningPathsRepository>().clearCache();
    if (sl.isRegistered<HomeBloc>()) {
      sl<HomeBloc>().add(const LoadActiveLearningPath(forceRefresh: true));
    }
  }

  /// Replay app walkthrough by resetting all walkthrough seen states.
  Future<void> _replayWalkthrough(BuildContext context) async {
    unawaited(showSettingsLoader(context));

    try {
      await sl<WalkthroughRepository>().resetAll();

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
        showAppSnackBar(
          context,
          context.tr(TranslationKeys.settingsReplayWalkthroughSuccess),
          tone: AppSnackTone.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
        showAppSnackBar(
          context,
          context.tr(TranslationKeys.settingsReplayWalkthroughError),
          tone: AppSnackTone.error,
        );
      }
    }
  }

  Future<void> _launchExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
