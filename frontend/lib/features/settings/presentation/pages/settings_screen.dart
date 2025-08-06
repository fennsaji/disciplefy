import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart' as auth_states;
import '../../domain/entities/theme_mode_entity.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';

/// Settings Screen with proper AuthBloc integration
/// Handles both authenticated and anonymous users
/// Features proper logout logic following SOLID principles
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => sl<SettingsBloc>()..add(LoadSettings()),
        child: const _SettingsScreenContent(),
      );
}

class _SettingsScreenContent extends StatelessWidget {
  const _SettingsScreenContent();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: BlocListener<AuthBloc, auth_states.AuthState>(
          listener: (context, authState) {
            if (authState is auth_states.UnauthenticatedState) {
              // Navigate to login screen after successful logout
              context.go('/login');
            } else if (authState is auth_states.AuthErrorState) {
              // Show error message
              _showSnackBar(context, authState.message, AppTheme.errorColor);
            }
          },
          child: BlocConsumer<SettingsBloc, SettingsState>(
            listener: (context, state) {
              if (state is SettingsError) {
                _showSnackBar(context, state.message, AppTheme.errorColor);
              } else if (state is SettingsUpdateSuccess) {
                _showSnackBar(context, state.message, AppTheme.successColor);
              }
            },
            builder: (context, state) {
              if (state is SettingsLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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
                      // Settings Header
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 32),
                        child: Text(
                          'Settings',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),

                      // User Profile Section (only for authenticated users)
                      _buildUserProfileSection(context),

                      // Theme & Language Section - DISABLED
                      // _buildThemeLanguageSection(context, state),
                      // const SizedBox(height: 24),

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
                  'Failed to load settings',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppTheme.errorColor,
                  ),
                ),
              );
            },
          ),
        ),
      );

  /// User Profile Section - shows different content based on auth state
  Widget _buildUserProfileSection(BuildContext context) =>
      BlocBuilder<AuthBloc, auth_states.AuthState>(
        builder: (context, authState) {
          if (authState is auth_states.AuthenticatedState) {
            return Column(
              children: [
                _buildSection(
                  title: 'Account',
                  children: [
                    _buildUserProfileTile(context, authState),
                    if (!authState.isAnonymous) ...[
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
                      //   onTap: () => _showAccountSettingsBottomSheet(context, authState),
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

  /// User Profile Tile showing user info
  Widget _buildUserProfileTile(
          BuildContext context, auth_states.AuthenticatedState authState) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Profile Picture
            CircleAvatar(
              radius: 25,
              backgroundImage: authState.photoUrl != null
                  ? NetworkImage(authState.photoUrl!)
                  : null,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: authState.photoUrl == null
                  ? Icon(
                      authState.isAnonymous
                          ? Icons.person_outline
                          : Icons.person,
                      size: 25,
                      color: AppTheme.primaryColor,
                    )
                  : null,
            ),

            const SizedBox(width: 16),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authState.isAnonymous
                        ? 'Guest User'
                        : authState.displayName ?? 'User',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    authState.isAnonymous
                        ? 'Sign in to sync your data'
                        : authState.email ?? 'No email',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Sign In Button for Anonymous Users
            if (authState.isAnonymous)
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(
                  'Sign In',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
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
        title: 'Appearance',
        children: [
          _buildSettingsTile(
            context: context,
            icon: Icons.palette_outlined,
            title: 'Theme',
            subtitle: _getThemeDisplayName(state.settings.themeMode),
            trailing: _buildThemeSwitch(context, state),
            onTap: null,
          ),
          _buildDivider(),
          _buildSettingsTile(
            context: context,
            icon: Icons.language_outlined,
            title: 'Language',
            subtitle: _getLanguageDisplayName(state.settings.language),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.onSurfaceVariant,
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

  /// Account Section with AuthBloc integration
  Widget _buildAccountSection(BuildContext context) =>
      BlocBuilder<AuthBloc, auth_states.AuthState>(
        builder: (context, authState) {
          if (authState is auth_states.AuthenticatedState) {
            return _buildSection(
              title: 'Account Actions',
              children: [
                _buildSettingsTile(
                  context: context,
                  icon: Icons.logout_outlined,
                  title: 'Sign Out',
                  subtitle: authState.isAnonymous
                      ? 'Clear guest session'
                      : 'Sign out of your account',
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppTheme.onSurfaceVariant,
                  ),
                  onTap: () =>
                      _showLogoutDialog(context, authState.isAnonymous),
                  iconColor: AppTheme.errorColor,
                ),
              ],
            );
          }

          // For unauthenticated users, show sign in option
          return _buildSection(
            title: 'Account',
            children: [
              _buildSettingsTile(
                context: context,
                icon: Icons.login_outlined,
                title: 'Sign In',
                subtitle: 'Sign in to sync your data across devices',
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppTheme.onSurfaceVariant,
                ),
                onTap: () => context.go('/login'),
                iconColor: AppTheme.primaryColor,
              ),
            ],
          );
        },
      );

  /// About Section
  Widget _buildAboutSection(BuildContext context, SettingsLoaded state) =>
      _buildSection(
        title: 'About',
        children: [
          _buildSettingsTile(
            context: context,
            icon: Icons.info_outline,
            title: 'App Version',
            subtitle: state.settings.appVersion,
            trailing: null,
            onTap: null,
          ),
          _buildDivider(),
          _buildSettingsTile(
            context: context,
            icon: Icons.favorite_outline,
            title: 'Support Developer',
            subtitle: 'Help us improve the app',
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.onSurfaceVariant,
            ),
            onTap: () => _showSupportBottomSheet(context),
            iconColor: AppTheme.accentColor,
          ),
          _buildDivider(),
          _buildSettingsTile(
            context: context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'View our privacy policy',
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.onSurfaceVariant,
            ),
            onTap: () => _launchPrivacyPolicy(),
          ),
          _buildDivider(),
          _buildSettingsTile(
            context: context,
            icon: Icons.feedback_outlined,
            title: 'Feedback',
            subtitle: 'Send us your feedback',
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.onSurfaceVariant,
            ),
            onTap: () => _showFeedbackBottomSheet(context),
          ),
        ],
      );

  /// Account Settings Bottom Sheet
  void _showAccountSettingsBottomSheet(
      BuildContext context, auth_states.AuthenticatedState authState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.3),
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
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),

            // Language Preference
            _buildAccountSettingItem(
              icon: Icons.language_outlined,
              title: 'Language Preference',
              subtitle: _getLanguageDisplayName(authState.languagePreference),
              onTap: () {
                Navigator.pop(context);
                _showLanguageBottomSheet(context, authState.languagePreference);
              },
            ),

            const SizedBox(height: 16),

            // Theme Preference
            _buildAccountSettingItem(
              icon: Icons.palette_outlined,
              title: 'Theme Preference',
              subtitle: _getThemeDisplayName(authState.themePreference == 'dark'
                  ? ThemeModeEntity.dark()
                  : ThemeModeEntity.light()),
              onTap: () {
                Navigator.pop(context);
                // Toggle theme
                final newTheme = authState.themePreference == 'dark'
                    ? ThemeModeEntity.light()
                    : ThemeModeEntity.dark();
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
        backgroundColor: const Color(0xFFFAFAFA), // Light background
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.1),
        title: Text(
          isAnonymous ? 'Clear Session' : 'Sign Out',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF333333), // Primary gray text
          ),
        ),
        content: Text(
          isAnonymous
              ? 'Are you sure you want to clear your guest session? Your data will be lost.'
              : 'Are you sure you want to sign out?',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xFF333333), // Primary gray text
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF888888), // Light gray for cancel
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF888888), // Light gray text
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
              backgroundColor: const Color(0xFF7A56DB), // Primary purple
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isAnonymous ? 'Clear' : 'Sign Out',
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
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
                height: 1.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(children: children),
          ),
        ],
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (iconColor ?? AppTheme.primaryColor)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: iconColor ?? AppTheme.primaryColor,
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
                          color: AppTheme.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.onSurfaceVariant,
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

  Widget _buildDivider() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        height: 1,
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
      );

  Widget _buildThemeSwitch(BuildContext context, SettingsLoaded state) =>
      Switch(
        value: state.settings.themeMode.isDarkMode,
        onChanged: (value) {
          final newTheme =
              value ? ThemeModeEntity.dark() : ThemeModeEntity.light();
          context.read<SettingsBloc>().add(ThemeModeChanged(newTheme));
        },
        activeColor: AppTheme.primaryColor,
        activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.3),
        inactiveThumbColor: AppTheme.onSurfaceVariant,
        inactiveTrackColor: AppTheme.onSurfaceVariant.withValues(alpha: 0.3),
      );

  Widget _buildNotificationSwitch(BuildContext context, SettingsLoaded state) =>
      Switch(
        value: state.settings.notificationsEnabled,
        onChanged: (value) {
          context.read<SettingsBloc>().add(ToggleNotifications(value));
        },
        activeColor: AppTheme.primaryColor,
        activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.3),
        inactiveThumbColor: AppTheme.onSurfaceVariant,
        inactiveTrackColor: AppTheme.onSurfaceVariant.withValues(alpha: 0.3),
      );

  void _showLanguageBottomSheet(BuildContext context, String currentLanguage) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select Language',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            _buildLanguageOption(
                context, 'en', 'English', '🇺🇸', currentLanguage),
            _buildLanguageOption(
                context, 'hi', 'Hindi', '🇮🇳', currentLanguage),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    String value,
    String label,
    String flag,
    String currentLanguage,
  ) {
    final isSelected = value == currentLanguage;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.read<SettingsBloc>().add(UpdateLanguage(value));
          Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.primaryColor,
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
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.2),
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
              'Support Developer',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Thank you for using Disciplefy! Your support helps us continue improving the app. If this app has blessed you or helped you in any way, and you’d like to encourage the work behind it, you can support it here by buying me a coffee.',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textPrimary,
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
                      side: const BorderSide(color: AppTheme.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Close',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
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
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Support',
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Send Feedback',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Help us improve Disciplefy by sharing your thoughts and suggestions.',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textPrimary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _launchFeedback();
                },
                icon: const Icon(Icons.email_outlined),
                label: const Text('Send Email'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
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
        return 'Hindi';
      case 'ml':
        return 'Malayalam';
      default:
        return 'English';
    }
  }

  Future<void> _launchPrivacyPolicy() async {
    final uri = Uri.parse('https://disciplefy.com/privacy');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchFeedback() async {
    final uri =
        Uri.parse('mailto:fennsaji@gmail.com?subject=Disciplefy Feedback');
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
