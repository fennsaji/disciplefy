import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart' as auth_states;

/// User profile section widget for settings screen.
///
/// Displays user profile information when authenticated,
/// or shows guest status for anonymous users.
class UserProfileSection extends StatelessWidget {
  const UserProfileSection({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, auth_states.AuthState>(
        builder: (context, authState) {
          if (authState is auth_states.AuthenticatedState) {
            return _UserProfileTile(authState: authState);
          }
          return const _GuestProfileTile();
        },
      );
}

/// Profile tile for authenticated users
class _UserProfileTile extends StatelessWidget {
  final auth_states.AuthenticatedState authState;

  const _UserProfileTile({required this.authState});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            _buildProfileAvatar(),
            const SizedBox(width: 16),
            Expanded(child: _buildProfileInfo(context)),
          ],
        ),
      );

  Widget _buildProfileAvatar() => Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.person,
          size: 32,
          color: AppTheme.primaryColor,
        ),
      );

  Widget _buildProfileInfo(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            authState.user.userMetadata?['display_name']?.toString() ?? authState.user.email?.split('@')[0] ?? 'User',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            authState.user.email ?? 'No email',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          const _UserStatusChip(userType: 'google'), // Simplified for now
        ],
      );
}

/// Profile tile for guest users
class _GuestProfileTile extends StatelessWidget {
  const _GuestProfileTile();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            _buildGuestAvatar(),
            const SizedBox(width: 16),
            Expanded(child: _buildGuestInfo()),
          ],
        ),
      );

  Widget _buildGuestAvatar() => Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: AppTheme.onSurfaceVariant,
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.person_outline,
          size: 32,
          color: AppTheme.onSurfaceVariant,
        ),
      );

  Widget _buildGuestInfo() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Guest User',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sign in to sync your data',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          const _UserStatusChip(userType: 'guest'),
        ],
      );
}

/// Status chip showing user type
class _UserStatusChip extends StatelessWidget {
  final String userType;

  const _UserStatusChip({required this.userType});

  @override
  Widget build(BuildContext context) {
    final chipData = _getChipData(userType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipData.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            chipData.icon,
            size: 12,
            color: chipData.textColor,
          ),
          const SizedBox(width: 4),
          Text(
            chipData.label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: chipData.textColor,
            ),
          ),
        ],
      ),
    );
  }

  _ChipData _getChipData(String userType) {
    switch (userType.toLowerCase()) {
      case 'google':
        return _ChipData(
          label: 'Google',
          icon: Icons.account_circle,
          backgroundColor: AppTheme.successColor.withOpacity(0.1),
          textColor: AppTheme.successColor,
        );
      case 'guest':
        return _ChipData(
          label: 'Guest',
          icon: Icons.visibility_off,
          backgroundColor: AppTheme.warningColor.withOpacity(0.1),
          textColor: AppTheme.warningColor,
        );
      default:
        return _ChipData(
          label: 'User',
          icon: Icons.person,
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          textColor: AppTheme.primaryColor,
        );
    }
  }
}

/// Data class for chip configuration
class _ChipData {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;

  const _ChipData({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
  });
}
