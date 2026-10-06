import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/constants/legal_urls.dart';
import 'package:disciplefy_bible_study/core/constants/study_mode_preferences.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/auth_state_provider.dart';
import 'package:disciplefy_bible_study/core/services/font_scale_service.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/core/utils/platform_utils.dart';
import 'package:disciplefy_bible_study/core/widgets/locked_feature_wrapper.dart';
import 'package:disciplefy_bible_study/features/auth/domain/utils/auth_validator.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_event.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart'
    as auth_states;
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/email_verification_banner.dart';
import 'package:disciplefy_bible_study/features/feedback/presentation/widgets/feedback_bottom_sheet.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_bloc.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_event.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/bloc/settings_state.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_profile_card.dart';
import 'package:disciplefy_bible_study/core/widgets/status_message_view.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/bloc/settings_event.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheet.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheets.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/models/learning_path_download_model.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_path_download_service.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';
import 'package:disciplefy_bible_study/features/user_profile/data/services/user_profile_api_service.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/shared/widgets/content_language_sheet.dart';

/// Settings in the grouped-cards design.
///
/// Handles both authenticated and anonymous users. Uses the global
/// [SettingsBloc] so a theme change does not recreate the screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _SettingsScreenContent();
}

class _SettingsScreenContent extends StatefulWidget {
  const _SettingsScreenContent();

  @override
  State<_SettingsScreenContent> createState() => _SettingsScreenContentState();
}

class _SettingsScreenContentState extends State<_SettingsScreenContent> {
  /// True while the delete-account API call is in-flight.
  /// Used to show a loading overlay and to navigate straight to login
  /// (bypassing the currentUser guard that exists for sign-out).
  bool _isDeletingAccount = false;
  List<LearningPathDownloadModel> _downloadedPaths = [];

  @override
  void initState() {
    super.initState();
    _loadDownloadedPaths();
  }

  Future<void> _loadDownloadedPaths() async {
    final paths = await sl<LearningPathDownloadService>().getAllDownloads();
    if (mounted) {
      setState(() {
        _downloadedPaths = paths
            .where((p) => p.status == PathDownloadStatus.completed)
            .toList();
      });
    }
  }

  void _goBack() {
    // Check if we can pop, otherwise navigate to home.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Android back button: pop, or go home.
        _goBack();
      },
      child: Scaffold(
        backgroundColor: palette.page,
        appBar: SettingsTopBar(
          title: context.tr(TranslationKeys.settingsTitle),
          onBack: _goBack,
        ),
        body: Stack(
          children: [
            BlocListener<AuthBloc, auth_states.AuthState>(
              listener: (context, authState) {
                if (authState is auth_states.UnauthenticatedState) {
                  if (_isDeletingAccount) {
                    // Account just deleted — go straight to login.
                    context.go(AppRoutes.login);
                  } else if (Supabase.instance.client.auth.currentUser ==
                      null) {
                    // Regular sign-out — wait for session to be fully cleared.
                    context.go(AppRoutes.login);
                  }
                } else if (authState is auth_states.AuthErrorState) {
                  // Reset deleting flag so the overlay is dismissed.
                  if (_isDeletingAccount) {
                    setState(() => _isDeletingAccount = false);
                  }
                  showSettingsSnackBar(
                    context,
                    context.tr(TranslationKeys.commonErrorTryAgain),
                    Theme.of(context).colorScheme.error,
                  );
                }
              },
              child: BlocConsumer<SettingsBloc, SettingsState>(
                listener: (context, state) {
                  if (state is SettingsError) {
                    showSettingsSnackBar(
                      context,
                      context.tr(TranslationKeys.commonErrorTryAgain),
                      Theme.of(context).colorScheme.error,
                    );
                  } else if (state is SettingsUpdateSuccess) {
                    showSettingsSnackBar(
                        context, state.message, AppColors.success);
                  }
                },
                builder: (context, state) {
                  if (state is SettingsLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(settingsPrimaryFill),
                        strokeWidth: 3,
                      ),
                    );
                  }
                  if (state is SettingsLoaded) {
                    return ListenableBuilder(
                      listenable: sl<AuthStateProvider>(),
                      builder: (context, _) =>
                          _buildSettingsList(context, state),
                    );
                  }
                  return StatusMessageView(
                    key: const Key('settings_load_failed'),
                    icon: Icons.cloud_off_rounded,
                    title: context.tr(TranslationKeys.settingsFailedToLoad),
                    actions: [
                      PopupPrimaryButton(
                        key: const Key('settings_load_retry'),
                        label: context.tr(TranslationKeys.commonRetry),
                        icon: Icons.refresh_rounded,
                        onPressed: () =>
                            context.read<SettingsBloc>().add(LoadSettings()),
                      ),
                    ],
                  );
                },
              ),
            ),
            // Loading overlay while delete-account API is in-flight.
            if (_isDeletingAccount)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: const SettingsLoaderCard(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context, SettingsLoaded state) {
    final authProvider = sl<AuthStateProvider>();
    final isAuthenticated = authProvider.isAuthenticated;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        if (isAuthenticated) ...[
          SettingsProfileCard(
            name: authProvider.profileBasedDisplayName,
            email: authProvider.userEmail ??
                context.tr(TranslationKeys.settingsNoEmail),
            photoUrl: authProvider.profilePictureUrl,
            editTooltip: context.tr(TranslationKeys.settingsEditNameTitle),
            onEditName: () => _showEditNameDialog(context, authProvider),
          ),
          // Email verification lives here rather than on Home: it is rarely
          // relevant, but it is the only way to resend the link, so it must
          // stay reachable somewhere.
          BlocProvider.value(
            value: context.read<AuthBloc>(),
            child: const EmailVerificationBanner(),
          ),
          ..._youSection(context),
        ],
        ..._preferencesSection(context, state),
        if (isAuthenticated) ..._studySection(context, authProvider),
        ..._helpSection(context),
        ..._aboutSection(context, state),
        ..._accountSection(context, isAuthenticated),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Sections
  // -------------------------------------------------------------------------

  String _userPlan() => currentPlanCode(sl<TokenBloc>().state);

  List<Widget> _youSection(BuildContext context) {
    final userPlan = _userPlan();
    // Respects the feature's display_mode (hidden vs locked).
    final config = sl<SystemConfigService>();
    final showProgress = !config.shouldHideFeature('leaderboard', userPlan);
    final showReflections = !config.shouldHideFeature('reflections', userPlan);

    return [
      SettingsSectionLabel(context.tr(TranslationKeys.settingsSectionYou)),
      SettingsGroup(
        children: [
          // My Progress — gamification stats dashboard.
          if (showProgress)
            LockedFeatureWrapper(
              featureKey: 'leaderboard',
              child: SettingsRow(
                icon: Icons.emoji_events_outlined,
                tone: SettingsTone.gold,
                title: context.tr(TranslationKeys.gamificationTitle),
                subtitle: context.tr(TranslationKeys.gamificationSubtitle),
                onTap: () => context.push(AppRoutes.statsDashboard),
              ),
            ),
          if (showReflections)
            LockedFeatureWrapper(
              featureKey: 'reflections',
              child: SettingsRow(
                icon: Icons.edit_note_outlined,
                tone: SettingsTone.pink,
                title: context.tr(TranslationKeys.settingsReflectionJournal),
                subtitle: context
                    .tr(TranslationKeys.settingsReflectionJournalSubtitle),
                onTap: () => context.push(AppRoutes.reflectionJournal),
              ),
            ),
          // My Plan — unified plan and subscription management.
          SettingsRow(
            icon: Icons.workspace_premium_outlined,
            tone: SettingsTone.gold,
            title: context.tr(TranslationKeys.settingsMyPlan),
            subtitle: context.tr(TranslationKeys.settingsMyPlanSubtitle),
            onTap: () => context.push(AppRoutes.myPlan),
          ),
        ],
      ),
    ];
  }

  List<Widget> _preferencesSection(BuildContext context, SettingsLoaded state) {
    final offlineCount = _downloadedPaths.fold<int>(
      0,
      (sum, path) => sum + path.completedCount,
    );
    return [
      SettingsSectionLabel(
          context.tr(TranslationKeys.settingsSectionPreferences)),
      SettingsGroup(
        children: [
          SettingsRow(
            icon: Icons.palette_outlined,
            title: context.tr(TranslationKeys.settingsTheme),
            value: themeModeLabel(context, state.settings.themeMode.mode),
            onTap: () {
              Logger.debug('Theme tile onTap triggered - opening bottom sheet');
              showThemeSheet(context, state.settings.themeMode);
            },
          ),
          SettingsRow(
            icon: Icons.translate,
            title: context.tr(TranslationKeys.settingsAppLanguage),
            value: AppLanguage.fromCode(state.settings.language).displayName,
            onTap: () => showAppLanguageSheet(context, state.settings.language),
          ),
          // Separate from the app language: which language study guides,
          // learning paths and daily verses are generated in. Same sheet as
          // the Topics screen's menu.
          _ContentLanguageSubtitle(
            appLanguageCode: state.settings.language,
            builder: (subtitle) => SettingsRow(
              icon: Icons.menu_book_outlined,
              title: context.tr(TranslationKeys.settingsContentLanguage),
              subtitle: subtitle,
              onTap: () => showContentLanguageSheet(context),
            ),
          ),
          ListenableBuilder(
            listenable: sl<FontScaleService>(),
            builder: (context, _) => SettingsRow(
              icon: Icons.text_fields,
              title: context.tr(TranslationKeys.settingsTextSize),
              value: fontScaleLevelLabel(context, sl<FontScaleService>().level),
              onTap: () => showTextSizeSheet(context),
            ),
          ),
          SettingsRow(
            icon: Icons.notifications_none_outlined,
            tone: SettingsTone.sky,
            title: context.tr(TranslationKeys.settingsNotifications),
            subtitle: context.tr(TranslationKeys.settingsNotificationSubtitle),
            onTap: () => context.push('/notification-settings'),
          ),
          SettingsRow(
            icon: Icons.download_outlined,
            tone: SettingsTone.green,
            title: context.tr(TranslationKeys.settingsOfflineGuides),
            // Each downloaded path with its progress, or how to get one.
            subtitle: _downloadedPaths.isEmpty
                ? context.tr(TranslationKeys.settingsOfflineEmptySubtitle)
                : _downloadedPaths
                    .map((path) =>
                        '${path.learningPathTitle} · ${context.tr(TranslationKeys.settingsOfflinePathProgress, {
                              'done': '${path.completedCount}',
                              'total': '${path.totalCount}',
                            })}')
                    .join('\n'),
            value: offlineCount > 0 ? '$offlineCount' : null,
            // Deleting happens on that screen; refresh the count on return.
            onTap: () => context
                .push('/offline-guides')
                .then((_) => _loadDownloadedPaths()),
          ),
        ],
      ),
    ];
  }

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
            icon: Icons.auto_awesome_outlined,
            title: context.tr(TranslationKeys.settingsRetakeQuestionnaire),
            subtitle:
                context.tr(TranslationKeys.settingsRetakeQuestionnaireSubtitle),
            onTap: () => _navigateToQuestionnaire(context),
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

  List<Widget> _helpSection(BuildContext context) => [
        SettingsSectionLabel(context.tr(TranslationKeys.settingsHelpSupport)),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.chat_bubble_outline_rounded,
              title: context.tr(TranslationKeys.settingsFeedback),
              subtitle: context.tr(TranslationKeys.settingsFeedbackSubtitle),
              onTap: () => showFeedbackBottomSheet(context),
            ),
            SettingsRow(
              icon: Icons.receipt_long_outlined,
              tone: SettingsTone.gold,
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

  List<Widget> _aboutSection(BuildContext context, SettingsLoaded state) => [
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
              tone: SettingsTone.gold,
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
              value: state.settings.appVersion,
            ),
          ],
        ),
      ];

  List<Widget> _accountSection(BuildContext context, bool isAuthenticated) => [
        SettingsSectionLabel(context.tr(TranslationKeys.settingsAccount)),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.block,
              title: context.tr(TranslationKeys.settingsBlockedUsers),
              subtitle:
                  context.tr(TranslationKeys.settingsBlockedUsersSubtitle),
              onTap: () => context.push(AppRoutes.blockedUsers),
            ),
            if (isAuthenticated) ...[
              SettingsRow(
                icon: Icons.logout_rounded,
                title: context.tr(TranslationKeys.settingsSignOut),
                subtitle: context.tr(TranslationKeys.settingsSignOutOfAccount),
                destructive: true,
                onTap: () => _showLogoutDialog(context),
              ),
              SettingsRow(
                icon: Icons.delete_outline_rounded,
                title: context.tr(TranslationKeys.settingsDeleteAccount),
                subtitle:
                    context.tr(TranslationKeys.settingsDeleteAccountSubtitle),
                destructive: true,
                onTap: () => _showDeleteAccountDialog(context),
              ),
            ] else
              SettingsRow(
                icon: Icons.login_rounded,
                title: context.tr(TranslationKeys.settingsSignIn),
                subtitle: context.tr(TranslationKeys.settingsSignInToSync),
                onTap: () => context.go('/login'),
              ),
          ],
        ),
      ];

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  /// Navigate to the personalization questionnaire.
  void _navigateToQuestionnaire(BuildContext context) {
    context.push('/personalization-questionnaire').then((_) {
      // Clear LearningPaths repository cache so Study Topics gets fresh data.
      sl<LearningPathsRepository>().clearCache();
      // Refresh all personalization-dependent data.
      sl<HomeBloc>().add(const LoadForYouTopics(forceRefresh: true));
      sl<HomeBloc>().add(const LoadActiveLearningPath(forceRefresh: true));
    });
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

  /// Lets the user set or correct their display name.
  ///
  /// Writes to two places, both needed: the Supabase auth metadata
  /// (`full_name`/`name`) that fellowship member lists and post authors read
  /// directly, and `user_profiles.first_name`/`last_name`, which is what
  /// Settings itself and the rest of the app read first. Writing only one
  /// would leave the other showing the old name.
  Future<void> _showEditNameDialog(
    BuildContext context,
    AuthStateProvider authProvider,
  ) async {
    final controller = TextEditingController(
      text: authProvider.profileBasedDisplayNameOrEmpty,
    );
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final palette = ReaderPalette.of(dialogContext);
        return SettingsDialog(
          title: dialogContext.tr(TranslationKeys.settingsEditNameTitle),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: AppFonts.inter(fontSize: 15, color: palette.text),
              decoration: InputDecoration(
                hintText:
                    dialogContext.tr(TranslationKeys.settingsEditNameHint),
                filled: true,
                fillColor: palette.raised,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: palette.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: palette.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: palette.accentIcon, width: 1.5),
                ),
              ),
              validator: (value) => AuthValidator.isValidFullName(value ?? '')
                  ? null
                  : dialogContext.tr(TranslationKeys.settingsEditNameInvalid),
            ),
          ),
          actions: [
            SettingsButton(
              label: dialogContext.tr(TranslationKeys.commonCancel),
              kind: SettingsButtonKind.neutral,
              height: 46,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            SettingsButton(
              label: dialogContext.tr(TranslationKeys.settingsEditNameSave),
              height: 46,
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    final fullName = controller.text.trim();
    final nameParts = fullName.split(RegExp(r'\s+'));
    final firstName = nameParts.first;
    final lastName = nameParts.length > 1 ? nameParts.skip(1).join(' ') : null;

    try {
      // Auth metadata first: it's what fellowship reads, and it's the part a
      // user actually opened this dialog to fix.
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'full_name': fullName, 'name': fullName}),
      );

      final profileResult = await UserProfileApiService().syncOAuthProfile({
        'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
      });

      if (!context.mounted) return;

      if (profileResult.isLeft()) {
        // The part that matters (fellowship display) is already saved; only
        // the local profile mirror failed.
        Logger.warning(
            'Name saved to auth but user_profiles sync failed: $profileResult');
      }

      context.read<AuthBloc>().add(const RefreshUserProfileRequested());

      showAppSnackBar(
        context,
        context.tr(TranslationKeys.settingsEditNameSuccess),
        tone: AppSnackTone.success,
      );
    } catch (e) {
      Logger.error('Failed to update display name', error: e);
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        context.tr(TranslationKeys.settingsEditNameFailed),
        tone: AppSnackTone.error,
      );
    }
  }

  /// Sign-out confirmation; dispatches [SignOutRequested].
  void _showLogoutDialog(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) => SettingsDialog(
        title: dialogContext.tr(TranslationKeys.settingsSignOutTitle),
        content: Text(dialogContext.tr(TranslationKeys.settingsSignOutMessage)),
        actions: [
          SettingsButton(
            label: dialogContext.tr(TranslationKeys.commonCancel),
            kind: SettingsButtonKind.neutral,
            height: 46,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          SettingsButton(
            label: dialogContext.tr(TranslationKeys.settingsSignOut),
            height: 46,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              authBloc.add(const SignOutRequested());
            },
          ),
        ],
      ),
    );
  }

  /// Delete-account confirmation; dispatches [DeleteAccountRequested].
  void _showDeleteAccountDialog(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) {
        final red = SettingsToneColors.of(dialogContext, SettingsTone.red);
        return SettingsDialog(
          title: dialogContext.tr(TranslationKeys.settingsDeleteAccountTitle),
          titleColor: red.foreground,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DeleteAccountWarningBox(
                title: dialogContext
                    .tr(TranslationKeys.settingsDeleteAccountLoseTitle),
                items: [
                  dialogContext
                      .tr(TranslationKeys.settingsDeleteAccountLoseGuides),
                  dialogContext
                      .tr(TranslationKeys.settingsDeleteAccountLoseVerses),
                  dialogContext
                      .tr(TranslationKeys.settingsDeleteAccountLoseProgress),
                  dialogContext
                      .tr(TranslationKeys.settingsDeleteAccountLosePlan),
                ],
              ),
              const SizedBox(height: 14),
              Text(dialogContext
                  .tr(TranslationKeys.settingsDeleteAccountMessage)),
            ],
          ),
          actions: [
            SettingsButton(
              label: dialogContext.tr(TranslationKeys.commonCancel),
              kind: SettingsButtonKind.neutral,
              height: 46,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            SettingsButton(
              label: dialogContext
                  .tr(TranslationKeys.settingsDeleteAccountConfirm),
              kind: SettingsButtonKind.destructive,
              height: 46,
              onPressed: () {
                Navigator.of(dialogContext).pop();
                setState(() => _isDeletingAccount = true);
                authBloc.add(const DeleteAccountRequested());
              },
            ),
          ],
        );
      },
    );
  }
}

/// Red-tinted box listing what deleting the account removes.
class DeleteAccountWarningBox extends StatelessWidget {
  final String title;
  final List<String> items;

  const DeleteAccountWarningBox({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final red = SettingsToneColors.of(context, SettingsTone.red);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: palette.isDark
            ? red.foreground.withValues(alpha: 0.08)
            : const Color(0xFFFEF1F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: red.foreground.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 20, color: red.foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: red.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.close, size: 14, color: red.foreground),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: AppFonts.inter(
                        fontSize: 13.5,
                        color: palette.text,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Resolves the Content Language row's subtitle: the chosen language, or
/// "Same as app language (X)". Rebuilds when either language changes, since
/// "Default" follows the app language.
class _ContentLanguageSubtitle extends StatefulWidget {
  final String appLanguageCode;
  final Widget Function(String subtitle) builder;

  const _ContentLanguageSubtitle({
    required this.appLanguageCode,
    required this.builder,
  });

  @override
  State<_ContentLanguageSubtitle> createState() =>
      _ContentLanguageSubtitleState();
}

class _ContentLanguageSubtitleState extends State<_ContentLanguageSubtitle> {
  final _languageService = sl<LanguagePreferenceService>();
  StreamSubscription<AppLanguage>? _subscription;
  bool _isDefault = true;
  AppLanguage? _language;

  @override
  void initState() {
    super.initState();
    _subscription =
        _languageService.studyContentLanguageChanges.listen((_) => _load());
    _load();
  }

  @override
  void didUpdateWidget(covariant _ContentLanguageSubtitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appLanguageCode != widget.appLanguageCode) _load();
  }

  Future<void> _load() async {
    final isDefault = await _languageService.isStudyContentLanguageDefault();
    final language = await _languageService.getStudyContentLanguage();
    if (!mounted) return;
    setState(() {
      _isDefault = isDefault;
      _language = language;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLanguage = AppLanguage.fromCode(widget.appLanguageCode);
    final subtitle = _isDefault || _language == null
        ? context.tr(TranslationKeys.settingsContentLanguageFollowsApp,
            {'language': appLanguage.displayName})
        : _language!.displayName;
    return widget.builder(subtitle);
  }
}
