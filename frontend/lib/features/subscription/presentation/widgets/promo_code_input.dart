import 'package:flutter/material.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/subscription_v2_models.dart';

/// Promo Code Input Widget
///
/// Displays an input field for promotional codes with:
/// - Text input with validation
/// - Apply button
/// - Loading state during validation
/// - Success/error feedback
/// - Applied promo code display
class PromoCodeInput extends StatefulWidget {
  /// Callback when promo code is applied successfully
  final void Function(PromotionalCampaignModel campaign) onPromoApplied;

  /// Callback when promo code is removed
  final VoidCallback? onPromoRemoved;

  /// Callback to validate promo code (returns campaign if valid, null if invalid)
  final Future<PromotionalCampaignModel?> Function(String code) onValidate;

  /// Optional plan code to validate promo against
  final String? planCode;

  /// Initial promo code (if already applied)
  final PromotionalCampaignModel? initialPromo;

  const PromoCodeInput({
    super.key,
    required this.onPromoApplied,
    required this.onValidate,
    this.onPromoRemoved,
    this.planCode,
    this.initialPromo,
  });

  @override
  State<PromoCodeInput> createState() => _PromoCodeInputState();
}

class _PromoCodeInputState extends State<PromoCodeInput> {
  final TextEditingController _controller = TextEditingController();
  bool _isValidating = false;
  String? _errorMessage;
  PromotionalCampaignModel? _appliedPromo;

  @override
  void initState() {
    super.initState();
    _appliedPromo = widget.initialPromo;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleApply() async {
    final code = _controller.text.trim();

    if (code.isEmpty) {
      setState(() {
        _errorMessage = context.tr(TranslationKeys.promoCodeEmpty);
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    try {
      final campaign = await widget.onValidate(code);

      if (campaign != null) {
        // Valid promo code
        setState(() {
          _appliedPromo = campaign;
          _isValidating = false;
          _errorMessage = null;
        });
        widget.onPromoApplied(campaign);
        _controller.clear();
      } else {
        // Invalid promo code
        setState(() {
          _isValidating = false;
          _errorMessage = context.tr(TranslationKeys.promoCodeInvalid);
        });
      }
    } catch (e) {
      setState(() {
        _isValidating = false;
        _errorMessage = context.tr(TranslationKeys.promoCodeError);
      });
    }
  }

  void _handleRemove() {
    setState(() {
      _appliedPromo = null;
      _errorMessage = null;
    });
    widget.onPromoRemoved?.call();
  }

  @override
  Widget build(BuildContext context) {
    // If promo is applied, show applied state
    if (_appliedPromo != null) {
      return _buildAppliedPromo(context);
    }

    // Otherwise show input field
    return _buildInputField(context);
  }

  Widget _buildInputField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(TranslationKeys.promoCodeHave),
          style: AppFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_isValidating,
                decoration: InputDecoration(
                  hintText: context.tr(TranslationKeys.promoCodeEnter),
                  hintStyle: AppFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppTheme.errorColor,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: AppFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _handleApply(),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isValidating ? null : _handleApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: _isValidating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      context.tr(TranslationKeys.promoCodeApply),
                      style: AppFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 16,
                color: AppTheme.errorColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: AppFonts.inter(
                    fontSize: 12,
                    color: AppTheme.errorColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAppliedPromo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.successColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: AppTheme.successColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr(TranslationKeys.promoCodeApplied),
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.successColor,
                  ),
                ),
              ),
              IconButton(
                onPressed: _handleRemove,
                icon: Icon(
                  Icons.close,
                  size: 20,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: context.tr(TranslationKeys.promoCodeRemove),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.successColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _appliedPromo!.code,
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _appliedPromo!.discountDisplayText,
                    style: AppFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.warningColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_appliedPromo!.description != null) ...[
            const SizedBox(height: 8),
            Text(
              _appliedPromo!.description!,
              style: AppFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
