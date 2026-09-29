import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/subscription/data/models/subscription_v2_models.dart';

/// Promo code field in the ledger style: one raised row with a ticket
/// icon, the code and an Apply button.
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
    final palette = ReaderPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(TranslationKeys.promoCodeHave),
          style: AppFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _errorMessage != null
                  ? context.appError.withValues(alpha: 0.6)
                  : palette.hairline,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.confirmation_number_outlined,
                  size: 20, color: palette.gold),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const Key('promo_code_field'),
                  controller: _controller,
                  enabled: !_isValidating,
                  decoration: InputDecoration(
                    hintText: context.tr(TranslationKeys.promoCodeEnter),
                    hintMaxLines: 3,
                    hintStyle:
                        AppFonts.inter(fontSize: 14.5, color: palette.dim),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isDense: true,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: AppFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                    letterSpacing: 0.6,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _handleApply(),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const Key('promo_code_apply'),
                onPressed: _isValidating ? null : _handleApply,
                style: TextButton.styleFrom(
                  backgroundColor: palette.raised,
                  foregroundColor: palette.text,
                  disabledBackgroundColor: palette.raised,
                  minimumSize: const Size(72, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: _isValidating
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(palette.text),
                        ),
                      )
                    : Text(
                        context.tr(TranslationKeys.promoCodeApply),
                        style: AppFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                        ),
                      ),
              ),
            ],
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 16,
                color: context.appError,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: AppFonts.inter(
                    fontSize: 12.5,
                    color: context.appError,
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
    final palette = ReaderPalette.of(context);
    final green = context.appSuccess;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color:
            AppColors.success.withValues(alpha: palette.isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle_rounded, color: green, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(TranslationKeys.promoCodeApplied),
                  style: AppFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: green,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _appliedPromo!.code,
                      style: AppFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      _appliedPromo!.discountDisplayText,
                      style: AppFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.gold,
                      ),
                    ),
                  ],
                ),
                if (_appliedPromo!.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _appliedPromo!.description!,
                    style: AppFonts.inter(
                      fontSize: 12.5,
                      color: palette.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: _handleRemove,
            icon: Icon(Icons.close_rounded, size: 20, color: palette.muted),
            tooltip: context.tr(TranslationKeys.promoCodeRemove),
          ),
        ],
      ),
    );
  }
}
