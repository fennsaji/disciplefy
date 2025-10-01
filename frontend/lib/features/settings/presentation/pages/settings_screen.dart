import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/theme_service.dart';
import '../../../../core/services/auth_state_provider.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart' as auth_states;
import '../../../feedback/presentation/widgets/feedback_bottom_sheet.dart';
import '../../domain/entities/theme_mode_entity.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';

/// Settings Screen with proper AuthBloc integration
/// Handles both authenticated and anonymous users
/// Features proper logout logic following SOLID principles
/// Updated: Uses global SettingsBloc to avoid recreation on theme changes
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _SettingsScreenContent();
}

class _SettingsScreenContent extends StatelessWidget {
  const _SettingsScreenContent();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            onPressed: () {
              // Check if we can pop, otherwise navigate to home
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            icon: Icon(
              Icons.arrow_back_ios,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: Text(
            context.tr(TranslationKeys.settingsTitle),
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          centerTitle: true,
        ),
        body: BlocListener<AuthBloc, auth_states.AuthState>(
          listener: (context, authState) {
            if (authState is auth_states.UnauthenticatedState) {
              // Navigate to login screen after successful logout
              context.go('/login');
            } else if (authState is auth_states.AuthErrorState) {
              // Show error message
              _showSnackBar(context, authState.message,
                  Theme.of(context).colorScheme.error);
            }
          },
          child: BlocConsumer<SettingsBloc, SettingsState>(
            listener: (context, state) {
              if (state is SettingsError) {
                _showSnackBar(context, state.message,
                    Theme.of(context).colorScheme.error);
              } else if (state is SettingsUpdateSuccess) {
                _showSnackBar(context, state.message, Colors.green);
              }
            },
            builder: (context, state) {
              if (state is SettingsLoading) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary),
                    strokeWidth: 3,
                  ),
                );
              }

              if (state is SettingsLoaded) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Profile Section (only for authenticated users)
                      _buildUserProfileSection(context),

                      // Theme & Language Section - ENABLED
                      _buildThemeLanguageSection(context, state),
                      const SizedBox(height: 24),

                      // Notification Section - DISABLED
                      // _buildNotificationSection(context, state),
                      // const SizedBox(height: 24),

                      // Account Section
                      _buildAccountSection(context),
                      const SizedBox(height: 24),

                      // About Section
                      _buildAboutSection(context, state),
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              }

              return Center(
                child: Text(
                  context.tr(TranslationKeys.settingsFailedToLoad),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              );
            },
          ),
        ),
      );

  /// User Profile Section - shows different content based on auth state
  Widget _buildUserProfileSection(BuildContext context) => ListenableBuilder(
        listenable: sl<AuthStateProvider>(),
        builder: (context, _) {
          final authProvider = sl<AuthStateProvider>();

          if (authProvider.isAuthenticated) {
            return Column(
              children: [
                _buildSection(
                  title: context.tr(TranslationKeys.settingsAccount),
                  children: [
                    _buildUserProfileTile(context, authProvider),
                    if (!authProvider.isAnonymous) ...[
                      _buildDivider(),
                      // Account Settings - DISABLED (contained theme/language settings)
                      // _buildSettingsTile(
                      //   context: context,
                      //   icon: Icons.account_circle_outlined,
                      //   title: 'Account Settings',
                      //   subtitle: 'Manage your account preferences',
                      //   trailing: const Icon(
                      //     Icons.arrow_forward_ios,
                      //     size: 16,
                      //     color: AppTheme.onSurfaceVariant,
                      //   ),
                      //   onTap: () => _showAccountSettingsBottomSheet(context, authProvider),
                      // ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      );

  /// Build profile avatar with network image support
  Widget _buildProfileAvatar(
      BuildContext context, AuthStateProvider authProvider) {
    final profilePictureUrl = authProvider.profilePictureUrl;

    // Show network image if available and user is not anonymous
    if (profilePictureUrl != null && !authProvider.isAnonymous) {
      return CircleAvatar(
        radius: 25,
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        child: ClipOval(
          child: Image.network(
            profilePictureUrl,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              if (kDebugMode) {
                print('🖼️ [SETTINGS] Failed to load profile picture: $error');
              }
              // Return icon fallback on error
              return Icon(
                Icons.person,
                size: 25,
                color: Theme.of(context).colorScheme.primary,
              );
            },
          ),
        ),
      );
    }

    // Fallback to icon (anonymous users or no profile picture)
    return CircleAvatar(
      radius: 25,
      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      child: Icon(
        authProvider.isAnonymous ? Icons.person_outline : Icons.person,
        size: 25,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  /// User Profile Tile showing user info
  Widget _buildUserProfileTile(
          BuildContext context, AuthStateProvider authProvider) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Profile Picture with cached data support
            _buildProfileAvatar(context, authProvider),

            const SizedBox(width: 16),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authProvider.profileBasedDisplayName,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    authProvider.isAnonymous
                        ? context.tr(TranslationKeys.settingsSignInToSync)
                        : authProvider.userEmail ??
                            context.tr(TranslationKeys.settingsNoEmail),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Sign In Button for Anonymous Users
            if (authProvider.isAnonymous)
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(
                  context.tr(TranslationKeys.settingsSignIn),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      );

  /// Theme & Language Section
  Widget _buildThemeLanguageSection(
          BuildContext context, SettingsLoaded state) =>
      _buildSection(
        title: context.tr(TranslationKeys.settingsAppearance),
        children: [
          _buildSettingsTile(
            context: context,
            icon: Icons.palette_outlined,
            title: context.tr(TranslationKeys.settingsTheme),
            subtitle: _getThemeDisplayName(state.settings.themeMode),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            onTap: () {
              debugPrint('Theme tile onTap triggered - opening bottom sheet');
              _showThemeBottomSheet(context, state.settings.themeMode);
            },
          ),
          _buildDivider(),
          _buildSettingsTile(
            context: context,
            icon: Icons.language_outlined,
            title: context.tr(TranslationKeys.settingsContentLanguage),
            subtitle: _getLanguageDisplayName(state.settings.language),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            onTap: () =>
                _showLanguageBottomSheet(context, state.settings.language),
          ),
        ],
      );

  /// Notification Section
  Widget _buildNotificationSection(
          BuildContext context, SettingsLoaded state) =>
      _buildSection(
        title: 'Notifications',
        children: [
          _buildSettingsTile(
            context: context,
            icon: Icons.notifications_outlined,
            title: 'Push Notifications',
            subtitle: 'Receive study reminders and updates',
            trailing: _buildNotificationSwitch(context, state),
            onTap: null,
          ),
        ],
      );

  /// Account Section with AuthStateProvider integration
  Widget _buildAccountSection(BuildContext context) => ListenableBuilder(
        listenable: sl<AuthStateProvider>(),
        builder: (context, _) {
          final authProvider = sl<AuthStateProvider>();

          if (authProvider.isAuthenticated) {
            return _buildSection(
              title: context.tr(TranslationKeys.settingsAccountActions),
              children: [
                _buildSettingsTile(
                  context: context,
                  icon: Icons.logout_outlined,
                  title: context.tr(TranslationKeys.settingsSignOut),
                  subtitle: authProvider.isAnonymous
                      ? context.tr(TranslationKeys.settingsClearGuestSession)
                      : context.tr(TranslationKeys.settingsSignOutOfAccount),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                  onTap: () =>
                      _showLogoutDialog(context, authProvider.isAnonymous),
                  iconColor: Theme.of(context).colorScheme.error,
                ),
              ],
            );
          }

          // For unauthenticated users, show sign in option
          return _buildSection(
            title: context.tr(TranslationKeys.settingsAccount),
            children: [
              _buildSettingsTile(
                context: context,
                icon: Icons.login_outlined,
                title: context.tr(TranslationKeys.settingsSignIn),
                subtitle: context.tr(TranslationKeys.settingsSignInToSync),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                onTap: () => context.go('/login'),
                iconColor: Theme.of(context).colorScheme.primary,
              ),
            ],
          );
        },
      );

  /// About Section
  Widget _buildAboutSection(BuildContext context, SettingsLoaded state) =>
      _buildSection(
        title: context.tr(TranslationKeys.settingsAbout),
        children: [
          _buildSettingsTile(
            context: context,
            icon: Icons.info_outline,
            title: context.tr(TranslationKeys.settingsAppVersion),
            subtitle: state.settings.appVersion,
            trailing: null,
            onTap: null,
          ),
          _buildDivider(),
          _buildSettingsTile(
            context: context,
            icon: Icons.favorite_outline,
            title: context.tr(TranslationKeys.settingsSupportDeveloper),
            subtitle:
                context.tr(TranslationKeys.settingsSupportDeveloperSubtitle),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            onTap: () => _showSupportBottomSheet(context),
            iconColor: AppTheme.accentColor,
          ),
          _buildDivider(),
          _buildSettingsTile(
            context: context,
            icon: Icons.privacy_tip_outlined,
            title: context.tr(TranslationKeys.settingsPrivacyPolicy),
            subtitle: context.tr(TranslationKeys.settingsPrivacyPolicySubtitle),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            onTap: () => _launchPrivacyPolicy(),
          ),
          _buildDivider(),
          _buildSettingsTile(
            context: context,
            icon: Icons.feedback_outlined,
            title: context.tr(TranslationKeys.settingsFeedback),
            subtitle: context.tr(TranslationKeys.settingsFeedbackSubtitle),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            onTap: () => _showFeedbackBottomSheet(context),
          ),
        ],
      );

  /// Account Settings Bottom Sheet
  void _showAccountSettingsBottomSheet(
      BuildContext context, AuthStateProvider authProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Account Settings',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),

            // Language Preference
            _buildAccountSettingItem(
              icon: Icons.language_outlined,
              title: 'Language Preference',
              subtitle:
                  'English', // Default since AuthStateProvider doesn't expose language preference
              onTap: () {
                Navigator.pop(context);
                _showLanguageBottomSheet(context, 'en'); // Default to English
              },
            ),

            const SizedBox(height: 16),

            // Theme Preference
            _buildAccountSettingItem(
              icon: Icons.palette_outlined,
              title: 'Theme Preference',
              subtitle:
                  'System Default', // Default since AuthStateProvider doesn't expose theme preference
              onTap: () {
                Navigator.pop(context);
                // Toggle to light theme as default
                final newTheme = ThemeModeEntity.light();
                context.read<SettingsBloc>().add(ThemeModeChanged(newTheme));
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppTheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );

  /// Logout confirmation dialog with AuthBloc integration
  void _showLogoutDialog(BuildContext context, bool isAnonymous) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.1),
        title: Text(
          isAnonymous
              ? context.tr(TranslationKeys.settingsClearSession)
              : context.tr(TranslationKeys.settingsSignOutTitle),
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          isAnonymous
              ? context.tr(TranslationKeys.settingsClearSessionMessage)
              : context.tr(TranslationKeys.settingsSignOutMessage),
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              context.tr(TranslationKeys.commonCancel),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<AuthBloc>().add(const SignOutRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isAnonymous
                  ? context.tr(TranslationKeys.settingsClear)
                  : context.tr(TranslationKeys.settingsSignOut),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Include all the helper methods from the original settings screen
  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) =>
      Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                title,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                  height: 1.2,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(children: children),
            ),
          ],
        ),
      );

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget? trailing,
    required VoidCallback? onTap,
    Color? iconColor,
  }) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            debugPrint('Settings tile tapped: $title');
            if (onTap != null) {
              onTap();
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (iconColor ?? Theme.of(context).colorScheme.primary)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: iconColor ?? Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onBackground,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing,
                ],
              ],
            ),
          ),
        ),
      );

  Widget _buildDivider() => Builder(
        builder: (context) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          height: 1,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        ),
      );

  Widget _buildThemeSwitch(BuildContext context, SettingsLoaded state) =>
      Switch(
        value: state.settings.themeMode.isDarkMode,
        onChanged: (value) {
          final newTheme =
              value ? ThemeModeEntity.dark() : ThemeModeEntity.light();
          context.read<SettingsBloc>().add(ThemeModeChanged(newTheme));
        },
        activeColor: Theme.of(context).colorScheme.primary,
        activeTrackColor:
            Theme.of(context).colorScheme.primary.withOpacity(0.3),
        inactiveThumbColor:
            Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        inactiveTrackColor:
            Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
      );

  Widget _buildNotificationSwitch(BuildContext context, SettingsLoaded state) =>
      Switch(
        value: state.settings.notificationsEnabled,
        onChanged: (value) {
          context.read<SettingsBloc>().add(ToggleNotifications(value));
        },
        activeColor: Theme.of(context).colorScheme.primary,
        activeTrackColor:
            Theme.of(context).colorScheme.primary.withOpacity(0.3),
        inactiveThumbColor:
            Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        inactiveTrackColor:
            Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
      );

  void _showThemeBottomSheet(
      BuildContext context, ThemeModeEntity currentTheme) {
    debugPrint(
        'Opening theme bottom sheet - Current theme: ${currentTheme.mode}');
    final settingsBloc = BlocProvider.of<SettingsBloc>(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (builderContext) => Container(
        decoration: BoxDecoration(
          color: Theme.of(builderContext).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(builderContext)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr(TranslationKeys.settingsSelectTheme),
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(builderContext).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            _buildThemeOption(
              builderContext,
              settingsBloc,
              ThemeModeEntity.system(
                  isDarkMode: currentTheme
                      .isDarkMode), // Match current system state for proper selection
              context.tr(TranslationKeys.settingsSystemDefault),
              Icons.brightness_auto,
              context.tr(TranslationKeys.settingsSystemDefaultSubtitle),
              currentTheme,
            ),
            _buildThemeOption(
              builderContext,
              settingsBloc,
              ThemeModeEntity.light(),
              context.tr(TranslationKeys.settingsLightMode),
              Icons.light_mode,
              context.tr(TranslationKeys.settingsLightModeSubtitle),
              currentTheme,
            ),
            _buildThemeOption(
              builderContext,
              settingsBloc,
              ThemeModeEntity.dark(),
              context.tr(TranslationKeys.settingsDarkMode),
              Icons.dark_mode,
              context.tr(TranslationKeys.settingsDarkModeSubtitle),
              currentTheme,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showLanguageBottomSheet(BuildContext context, String currentLanguage) {
    final settingsBloc = BlocProvider.of<SettingsBloc>(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (builderContext) => Container(
        decoration: BoxDecoration(
          color: Theme.of(builderContext).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(builderContext)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr(TranslationKeys.settingsSelectLanguage),
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(builderContext).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            _buildLanguageOption(
                builderContext, settingsBloc, 'en', 'English', currentLanguage),
            _buildLanguageOption(
                builderContext, settingsBloc, 'hi', 'हिन्दी', currentLanguage),
            _buildLanguageOption(
                builderContext, settingsBloc, 'ml', 'മലയാളം', currentLanguage),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    SettingsBloc settingsBloc,
    ThemeModeEntity themeOption,
    String title,
    IconData icon,
    String subtitle,
    ThemeModeEntity currentTheme,
  ) {
    final isSelected = themeOption.mode == currentTheme.mode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          debugPrint('Theme option selected: ${themeOption.mode}');
          settingsBloc.add(ThemeModeChanged(themeOption));
          Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6))
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    SettingsBloc settingsBloc,
    String value,
    String label,
    String currentLanguage,
  ) {
    final isSelected = value == currentLanguage;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          settingsBloc.add(UpdateLanguage(value));
          Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onBackground,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSupportBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.favorite,
                size: 40,
                color: AppTheme.accentColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr(TranslationKeys.settingsSupportTitle),
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr(TranslationKeys.settingsSupportMessage),
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onBackground,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      context.tr(TranslationKeys.settingsClose),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _launchBuyMeCoffee();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      context.tr(TranslationKeys.settingsSupport),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showFeedbackBottomSheet(BuildContext context) {
    // Use the existing feedback bottom sheet from the feedback feature
    showFeedbackBottomSheet(context);
  }

  void _showSnackBar(
      BuildContext context, String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _getThemeDisplayName(ThemeModeEntity themeMode) {
    switch (themeMode.mode) {
      case AppThemeMode.light:
        return 'Light Mode';
      case AppThemeMode.dark:
        return 'Dark Mode';
      case AppThemeMode.system:
        return 'System Default';
    }
  }

  String _getLanguageDisplayName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'hi':
        return 'हिन्दी';
      case 'ml':
        return 'മലയാളം';
      default:
        return 'English';
    }
  }

  Future<void> _launchPrivacyPolicy() async {
    final uri = Uri.parse('https://policies.disciplefy.in/privacy-policy');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchFeedback() async {
    final uri =
        Uri.parse('mailto:feedback@disciplefy.in?subject=Disciplefy Feedback');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchBuyMeCoffee() async {
    final uri = Uri.parse('https://buymeacoffee.com/fennsaji');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
