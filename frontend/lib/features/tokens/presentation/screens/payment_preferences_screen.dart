import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/error_widget.dart' as custom;
import '../../domain/entities/payment_preferences.dart';
import '../bloc/payment_method_bloc.dart';

/// A screen that allows users to view and edit their payment preferences
///
/// This screen provides an interface for users to configure their payment
/// settings including auto-save preferences, default payment methods,
/// wallet preferences, and security options.
class PaymentPreferencesScreen extends StatefulWidget {
  /// Route name for the payment preferences screen
  static const String routeName = '/payment-preferences';

  const PaymentPreferencesScreen({super.key});

  @override
  State<PaymentPreferencesScreen> createState() =>
      _PaymentPreferencesScreenState();
}

class _PaymentPreferencesScreenState extends State<PaymentPreferencesScreen> {
  PaymentPreferences? _preferences;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    context.read<PaymentMethodBloc>().add(LoadPaymentPreferences());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceColor,
      appBar: CustomAppBar(
        title: 'Payment Preferences',
        backgroundColor: AppColors.surfaceColor,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _savePreferences,
              child: Text(
                'Save',
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: BlocConsumer<PaymentMethodBloc, PaymentMethodState>(
        listener: (context, state) {
          if (state is PaymentMethodError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.errorColor,
              ),
            );
          } else if (state is PaymentPreferencesLoaded) {
            setState(() {
              _preferences = state.preferences;
              _hasChanges = false;
            });
          } else if (state is PaymentPreferencesUpdated) {
            setState(() {
              _preferences = state.preferences;
              _hasChanges = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Preferences updated successfully'),
                backgroundColor: AppColors.successColor,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is PaymentPreferencesLoading) {
            return const LoadingWidget();
          } else if (state is PaymentMethodError && _preferences == null) {
            return custom.AppErrorWidget(
              message: state.message,
              onRetry: () {
                context.read<PaymentMethodBloc>().add(LoadPaymentPreferences());
              },
            );
          }

          return _buildPreferencesContent();
        },
      ),
    );
  }

  Widget _buildPreferencesContent() {
    if (_preferences == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGeneralSettings(),
          const SizedBox(height: 32),
          _buildPaymentMethodPreferences(),
          const SizedBox(height: 32),
          _buildSecurityPrivacy(),
        ],
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'General Settings',
          'Configure your payment experience',
        ),
        const SizedBox(height: 16),
        _buildPreferenceCard([
          _buildSwitchTile(
            title: 'Auto-save Payment Methods',
            subtitle: 'Automatically save payment methods for future use',
            value: _preferences!.autoSavePaymentMethods ?? false,
            onChanged: (value) {
              setState(() {
                _preferences = _preferences!.copyWith(
                  autoSavePaymentMethods: value,
                );
                _hasChanges = true;
              });
            },
          ),
          const Divider(height: 1),
          _buildSwitchTile(
            title: 'Enable One-Click Purchase',
            subtitle: 'Use default payment method for quick purchases',
            value: _preferences!.enableOneClickPurchase ?? false,
            onChanged: (value) {
              setState(() {
                _preferences = _preferences!.copyWith(
                  enableOneClickPurchase: value,
                );
                _hasChanges = true;
              });
            },
          ),
        ]),
      ],
    );
  }

  Widget _buildPaymentMethodPreferences() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Payment Method Preferences',
          'Set your preferred payment types',
        ),
        const SizedBox(height: 16),
        _buildPreferenceCard([
          _buildDropdownTile(
            title: 'Default Payment Type',
            subtitle: 'Your preferred payment method type',
            value: _preferences!.defaultPaymentType,
            items: const [
              ('card', 'Credit/Debit Card'),
              ('upi', 'UPI'),
              ('netbanking', 'Net Banking'),
              ('wallet', 'Wallet'),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _preferences = _preferences!.copyWith(
                    defaultPaymentType: value,
                  );
                  _hasChanges = true;
                });
              }
            },
          ),
          const Divider(height: 1),
          _buildDropdownTile(
            title: 'Preferred Wallet',
            subtitle: 'Your go-to mobile wallet for payments',
            value: _preferences!.preferredWallet,
            items: const [
              ('google_pay', 'Google Pay'),
              ('phonepe', 'PhonePe'),
              ('paytm', 'Paytm'),
              ('amazon_pay', 'Amazon Pay'),
              ('mobikwik', 'MobiKwik'),
              ('freecharge', 'Freecharge'),
            ],
            onChanged: (value) {
              setState(() {
                _preferences = _preferences!.copyWith(
                  preferredWallet: value,
                );
                _hasChanges = true;
              });
            },
          ),
        ]),
      ],
    );
  }

  Widget _buildSecurityPrivacy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Security & Privacy',
          'Control how your payment data is handled',
        ),
        const SizedBox(height: 16),
        _buildPreferenceCard([
          _buildInfoTile(
            icon: Icons.security,
            title: 'Secure Token Storage',
            subtitle:
                'Payment methods are stored as secure tokens, never as raw card data',
          ),
          const Divider(height: 1),
          _buildInfoTile(
            icon: Icons.security,
            title: 'End-to-End Encryption',
            subtitle:
                'All payment data is encrypted during transmission and storage',
          ),
          const Divider(height: 1),
          _buildInfoTile(
            icon: Icons.privacy_tip,
            title: 'PCI DSS Compliant',
            subtitle: 'Our payment system meets the highest security standards',
          ),
        ]),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceCard(List<Widget> children) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: AppTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primaryColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required String? value,
    required List<(String, String)> items,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      title: Text(
        title,
        style: AppTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: items.map((item) {
              return DropdownMenuItem(
                value: item.$1,
                child: Text(item.$2),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: AppColors.primaryColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  void _savePreferences() {
    if (_preferences != null) {
      context.read<PaymentMethodBloc>().add(UpdatePaymentPreferencesEvent(
            autoSavePaymentMethods: _preferences!.autoSavePaymentMethods,
            preferredWallet: _preferences!.preferredWallet,
            enableOneClickPurchase: _preferences!.enableOneClickPurchase,
            defaultPaymentType: _preferences!.defaultPaymentType,
          ));
    }
  }
}
