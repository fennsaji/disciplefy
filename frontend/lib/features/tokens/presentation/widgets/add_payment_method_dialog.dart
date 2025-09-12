import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

/// A dialog widget for adding new payment methods to user's saved payment options.
///
/// Provides a form interface for users to input payment method details including
/// method type (card, UPI, net banking, wallet), provider information, security tokens,
/// and optional metadata like display names and default preferences.
///
/// Supports card-specific fields (brand, last 4 digits, expiry date) with appropriate
/// validation and input formatters for enhanced security and user experience.
class AddPaymentMethodDialog extends StatefulWidget {
  /// Callback function invoked when the user saves a new payment method.
  ///
  /// Parameters:
  /// - [methodType]: The type of payment method ('card', 'upi', 'netbanking', 'wallet')
  /// - [provider]: The payment provider name (e.g., 'HDFC Bank', 'Google Pay')
  /// - [token]: The secure payment token from the payment gateway
  /// - [lastFour]: Last 4 digits of card number (nullable, card-specific)
  /// - [brand]: Card brand name (nullable, card-specific, e.g., 'Visa', 'Mastercard')
  /// - [displayName]: User-friendly name for the payment method (nullable)
  /// - [isDefault]: Whether this should be set as the default payment method
  /// - [expiryMonth]: Card expiry month (nullable, card-specific, 1-12)
  /// - [expiryYear]: Card expiry year (nullable, card-specific)
  final Function(
    String methodType,
    String provider,
    String token,
    String? lastFour,
    String? brand,
    String? displayName,
    bool isDefault,
    int? expiryMonth,
    int? expiryYear,
  ) onSave;

  const AddPaymentMethodDialog({
    super.key,
    required this.onSave,
  });

  @override
  State<AddPaymentMethodDialog> createState() => _AddPaymentMethodDialogState();
}

class _AddPaymentMethodDialogState extends State<AddPaymentMethodDialog> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _tokenController = TextEditingController();
  final _lastFourController = TextEditingController();
  final _brandController = TextEditingController();
  final _providerController = TextEditingController();

  String _selectedMethodType = 'card';
  bool _isDefault = false;
  int? _expiryMonth;
  int? _expiryYear;

  final List<String> _methodTypes = ['card', 'upi', 'netbanking', 'wallet'];
  final List<String> _cardBrands = [
    'Visa',
    'Mastercard',
    'RuPay',
    'American Express'
  ];
  final List<String> _upiProviders = [
    'Google Pay',
    'PhonePe',
    'Paytm',
    'BHIM',
    'Amazon Pay'
  ];
  final List<String> _walletProviders = [
    'Paytm',
    'MobiKwik',
    'Freecharge',
    'Amazon Pay'
  ];

  @override
  void dispose() {
    _displayNameController.dispose();
    _tokenController.dispose();
    _lastFourController.dispose();
    _brandController.dispose();
    _providerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Add Payment Method',
                    style: AppTextStyles.headingMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMethodTypeSelector(),
                      const SizedBox(height: 16),
                      _buildDisplayNameField(),
                      const SizedBox(height: 16),
                      _buildProviderField(),
                      const SizedBox(height: 16),
                      _buildTokenField(),
                      const SizedBox(height: 16),
                      if (_selectedMethodType == 'card') ...[
                        _buildCardFields(),
                        const SizedBox(height: 16),
                      ],
                      _buildDefaultCheckbox(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _savePaymentMethod,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save'),
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

  Widget _buildMethodTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Method Type',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _methodTypes.map((type) {
            final isSelected = _selectedMethodType == type;
            return ChoiceChip(
              label: Text(_getMethodTypeLabel(type)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedMethodType = type;
                    _providerController.clear();
                    _brandController.clear();

                    // Clear card-specific fields when switching away from card
                    if (type != 'card') {
                      _lastFourController.clear();
                      _expiryMonth = null;
                      _expiryYear = null;
                    }
                  });
                }
              },
              selectedColor: AppColors.primaryColor.withOpacity(0.2),
              checkmarkColor: AppColors.primaryColor,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDisplayNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Display Name (Optional)',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _displayNameController,
          decoration: const InputDecoration(
            hintText: 'e.g., Personal Card, Work Account',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildProviderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Provider',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (_selectedMethodType == 'upi') ...[
          DropdownButtonFormField<String>(
            value: _providerController.text.isEmpty
                ? null
                : _providerController.text,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            items: _upiProviders.map((provider) {
              return DropdownMenuItem(
                value: provider,
                child: Text(provider),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _providerController.text = value;
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a UPI provider';
              }
              return null;
            },
          ),
        ] else if (_selectedMethodType == 'wallet') ...[
          DropdownButtonFormField<String>(
            value: _providerController.text.isEmpty
                ? null
                : _providerController.text,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            items: _walletProviders.map((provider) {
              return DropdownMenuItem(
                value: provider,
                child: Text(provider),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _providerController.text = value;
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a wallet provider';
              }
              return null;
            },
          ),
        ] else ...[
          TextFormField(
            controller: _providerController,
            decoration: InputDecoration(
              hintText: _selectedMethodType == 'card'
                  ? 'e.g., HDFC Bank, SBI, ICICI'
                  : 'e.g., HDFC Bank, SBI, ICICI',
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter provider name';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildTokenField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Token',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _tokenController,
          decoration: const InputDecoration(
            hintText: 'Secure token from payment gateway',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.next,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter payment token';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCardFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Brand',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _brandController.text.isEmpty
                        ? null
                        : _brandController.text,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: _cardBrands.map((brand) {
                      return DropdownMenuItem(
                        value: brand,
                        child: Text(brand),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _brandController.text = value;
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last 4 Digits',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _lastFourController,
                    decoration: const InputDecoration(
                      hintText: '1234',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter exactly 4 digits';
                      }
                      if (value.length != 4) {
                        return 'Enter exactly 4 digits';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expiry Month',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _expiryMonth,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(12, (index) {
                      final month = index + 1;
                      return DropdownMenuItem(
                        value: month,
                        child: Text(month.toString().padLeft(2, '0')),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        _expiryMonth = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Select expiry month';
                      }
                      return _validateExpiryDate();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expiry Year',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _expiryYear,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(20, (index) {
                      final year = DateTime.now().year + index;
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        _expiryYear = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Select expiry year';
                      }
                      return _validateExpiryDate();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDefaultCheckbox() {
    return CheckboxListTile(
      title: Text(
        'Set as default payment method',
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
      value: _isDefault,
      onChanged: (value) {
        setState(() {
          _isDefault = value ?? false;
        });
      },
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      activeColor: AppColors.primaryColor,
    );
  }

  String _getMethodTypeLabel(String type) {
    switch (type) {
      case 'card':
        return 'Card';
      case 'upi':
        return 'UPI';
      case 'netbanking':
        return 'Net Banking';
      case 'wallet':
        return 'Wallet';
      default:
        return type;
    }
  }

  /// Validates that the expiry date is not in the past.
  /// Returns error message if invalid, null if valid.
  String? _validateExpiryDate() {
    if (_selectedMethodType != 'card') return null;
    if (_expiryMonth == null || _expiryYear == null) return null;

    // Create expiry date at end of selected month
    final expiryDate = DateTime(_expiryYear!, _expiryMonth! + 1, 0);
    final today = DateTime.now();
    final endOfToday = DateTime(today.year, today.month + 1, 0);

    if (expiryDate.isBefore(endOfToday)) {
      return 'Card has expired';
    }
    return null;
  }

  void _savePaymentMethod() {
    if (_formKey.currentState!.validate()) {
      widget.onSave(
        _selectedMethodType,
        _providerController.text,
        _tokenController.text,
        _lastFourController.text.isEmpty ? null : _lastFourController.text,
        _brandController.text.isEmpty ? null : _brandController.text,
        _displayNameController.text.isEmpty
            ? null
            : _displayNameController.text,
        _isDefault,
        _expiryMonth,
        _expiryYear,
      );
      Navigator.of(context).pop();
    }
  }
}
