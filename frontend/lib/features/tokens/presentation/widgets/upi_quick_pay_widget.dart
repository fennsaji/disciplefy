import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

/// UPI Quick Pay Widget
///
/// Optimized UPI payment interface with:
/// - UPI ID input and validation
/// - QR code generation for payments
/// - Popular UPI app shortcuts
/// - One-tap payment initiation
class UPIQuickPayWidget extends StatefulWidget {
  final double amount;
  final String description;
  final Function(String upiId)? onUPIIdEntered;
  final Function(String appName)? onUPIAppSelected;
  final VoidCallback? onQRCodeRequested;

  const UPIQuickPayWidget({
    super.key,
    required this.amount,
    required this.description,
    this.onUPIIdEntered,
    this.onUPIAppSelected,
    this.onQRCodeRequested,
  });

  @override
  State<UPIQuickPayWidget> createState() => _UPIQuickPayWidgetState();
}

class _UPIQuickPayWidgetState extends State<UPIQuickPayWidget> {
  final TextEditingController _upiController = TextEditingController();
  bool _isUPIValid = false;
  String _selectedUPIApp = '';

  final List<UPIApp> _upiApps = [
    UPIApp(
      name: 'Google Pay',
      packageName: 'com.google.android.apps.nbu.paisa.user',
      icon: '🟢',
      isPopular: true,
    ),
    UPIApp(
      name: 'PhonePe',
      packageName: 'com.phonepe.app',
      icon: '🟣',
      isPopular: true,
    ),
    UPIApp(
      name: 'Paytm',
      packageName: 'net.one97.paytm',
      icon: '🔵',
      isPopular: true,
    ),
    UPIApp(
      name: 'BHIM',
      packageName: 'in.org.npci.upiapp',
      icon: '🟠',
    ),
    UPIApp(
      name: 'Amazon Pay',
      packageName: 'in.amazon.mShop.android.shopping',
      icon: '🟡',
    ),
    UPIApp(
      name: 'WhatsApp',
      packageName: 'com.whatsapp',
      icon: '🟢',
    ),
  ];

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPaymentSummary(),
        const SizedBox(height: 20),
        _buildUPIAppsSection(),
        const SizedBox(height: 20),
        _buildUPIIdSection(),
        const SizedBox(height: 20),
        _buildQRCodeSection(),
        const SizedBox(height: 16),
        _buildSecurityNote(),
      ],
    );
  }

  Widget _buildPaymentSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UPI Payment',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      widget.description,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${widget.amount.toStringAsFixed(2)}',
                    style: AppTextStyles.headingSmall.copyWith(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Amount',
                    style: AppTextStyles.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUPIAppsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pay with UPI App',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose your preferred UPI app for instant payment',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        _buildUPIAppsGrid(),
      ],
    );
  }

  Widget _buildUPIAppsGrid() {
    // Sort apps: popular first
    final sortedApps = [..._upiApps]
      ..sort((a, b) => a.isPopular == b.isPopular ? 0 : (a.isPopular ? -1 : 1));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: sortedApps.length,
      itemBuilder: (context, index) {
        final app = sortedApps[index];
        return _buildUPIAppTile(app);
      },
    );
  }

  Widget _buildUPIAppTile(UPIApp app) {
    final isSelected = _selectedUPIApp == app.name;

    return Material(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedUPIApp = isSelected ? '' : app.name;
          });

          if (widget.onUPIAppSelected != null && !isSelected) {
            widget.onUPIAppSelected!(app.name);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isSelected ? AppColors.primaryColor : AppColors.borderColor,
              width: isSelected ? 2 : 1,
            ),
            color: isSelected
                ? AppColors.primaryColor.withOpacity(0.05)
                : AppColors.surfaceColor,
          ),
          child: Stack(
            children: [
              if (app.isPopular)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.successColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        app.icon,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    app.name,
                    style: AppTextStyles.captionSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUPIIdSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter UPI ID',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pay directly using your UPI ID',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _upiController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'username@paytm, username@ybl, etc.',
            prefixIcon: Icon(
              Icons.alternate_email,
              color: AppColors.primaryColor,
            ),
            suffixIcon: _isUPIValid
                ? Icon(
                    Icons.check_circle,
                    color: AppColors.successColor,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _isUPIValid
                    ? AppColors.successColor
                    : AppColors.borderColor,
              ),
            ),
          ),
          onChanged: (value) {
            final isValid = _validateUPIId(value);
            if (isValid != _isUPIValid) {
              setState(() {
                _isUPIValid = isValid;
              });
            }

            if (isValid && widget.onUPIIdEntered != null) {
              widget.onUPIIdEntered!(value);
            }
          },
        ),
        if (_upiController.text.isNotEmpty && !_isUPIValid)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: AppColors.errorColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Please enter a valid UPI ID',
                  style: AppTextStyles.captionSmall.copyWith(
                    color: AppColors.errorColor,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildQRCodeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scan QR Code',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Scan with any UPI app to pay',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Material(
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onQRCodeRequested,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
                color: AppColors.surfaceColor,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.qr_code,
                      color: AppColors.primaryColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generate QR Code',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to generate payment QR code',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.textTertiary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.successColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.successColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.security,
            color: AppColors.successColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure UPI Payment',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your payment is protected by bank-level security',
                  style: AppTextStyles.captionSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _validateUPIId(String upiId) {
    // Basic UPI ID validation: must contain @ and have valid format
    final upiRegex =
        RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z][a-zA-Z0-9.-]{1,64}$');
    return upiRegex.hasMatch(upiId);
  }
}

/// UPI App Model
class UPIApp {
  final String name;
  final String packageName;
  final String icon;
  final bool isPopular;

  const UPIApp({
    required this.name,
    required this.packageName,
    required this.icon,
    this.isPopular = false,
  });
}
