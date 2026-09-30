import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/purchase_issue/domain/entities/purchase_issue_entity.dart';
import 'package:disciplefy_bible_study/features/purchase_issue/presentation/bloc/purchase_issue_bloc.dart';
import 'package:disciplefy_bible_study/features/purchase_issue/presentation/bloc/purchase_issue_event.dart';
import 'package:disciplefy_bible_study/features/purchase_issue/presentation/bloc/purchase_issue_state.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/purchase_history.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';
import 'package:disciplefy_bible_study/shared/widgets/sheet_scroll_view.dart';

// Conditional import for web image picker
import '../utils/issue_image_picker_stub.dart'
    if (dart.library.html) '../utils/issue_image_picker_web.dart';

/// Bottom sheet for reporting an issue with a purchase: transaction summary,
/// issue type, description, optional screenshots and a submit pill.
class ReportIssueBottomSheet extends StatefulWidget {
  final PurchaseHistory purchase;

  const ReportIssueBottomSheet({
    super.key,
    required this.purchase,
  });

  @override
  State<ReportIssueBottomSheet> createState() => _ReportIssueBottomSheetState();
}

class _ReportIssueBottomSheetState extends State<ReportIssueBottomSheet> {
  final TextEditingController _descriptionController = TextEditingController();
  PurchaseIssueType _selectedIssueType = PurchaseIssueType.other;

  static const int _minChars = 10;
  static const int _maxChars = 2000;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final dateFormatter = DateFormat('MMM dd, yyyy • hh:mm a');

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(kPopupRadius)),
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: BlocConsumer<PurchaseIssueBloc, PurchaseIssueState>(
        listener: (context, state) {
          if (state is PurchaseIssueSubmitSuccess) {
            showAppSnackBar(
              context,
              state.message,
              tone: AppSnackTone.success,
            );
            Future.delayed(const Duration(milliseconds: 500), () {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            });
          } else if (state is PurchaseIssueSubmitFailure) {
            showAppSnackBar(
              context,
              context.tr(TranslationKeys.commonErrorTryAgain),
              tone: AppSnackTone.error,
            );
          } else if (state is PurchaseIssueFormReady &&
              state.uploadError != null) {
            showAppSnackBar(
              context,
              state.uploadError!,
              tone: AppSnackTone.error,
            );
          }
        },
        builder: (context, state) {
          return SheetScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.viewInsetsOf(context).bottom +
                  MediaQuery.paddingOf(context).bottom +
                  20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHandle(palette),
                const SizedBox(height: 20),
                _buildHeader(context),
                const SizedBox(height: 20),
                _buildTransactionDetails(palette, dateFormatter),
                const SizedBox(height: 20),
                _buildIssueTypeDropdown(palette),
                const SizedBox(height: 16),
                _buildDescriptionInput(palette),
                const SizedBox(height: 16),
                _buildScreenshotSection(palette, state),
                const SizedBox(height: 24),
                _buildSubmitButton(palette, state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHandle(ReaderPalette palette) => Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: palette.outline,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildHeader(BuildContext context) => PopupHeader(
        centered: false,
        icon: const PopupIconCircle(
          icon: Icons.report_problem_outlined,
          tone: PopupTone.gold,
          size: 48,
        ),
        eyebrow: context.tr(TranslationKeys.reportIssueEyebrow),
        title: context.tr(TranslationKeys.reportIssueTitle),
        body: context.tr(TranslationKeys.reportIssueBody),
      );

  Widget _sectionLabel(ReaderPalette palette, String text) => Text(
        text,
        style: AppFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: palette.text,
        ),
      );

  Widget _buildTransactionDetails(
    ReaderPalette palette,
    DateFormat dateFormatter,
  ) {
    return PopupPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PopupEyebrow(
            context.tr(TranslationKeys.reportIssueTransactionDetails),
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 10),
          _buildDetailRow(
            palette,
            context.tr(TranslationKeys.reportIssueTokens),
            '${widget.purchase.tokenAmount}',
          ),
          _buildDetailRow(
            palette,
            context.tr(TranslationKeys.reportIssueAmount),
            '₹${widget.purchase.costRupees.toStringAsFixed(2)}',
          ),
          _buildDetailRow(
            palette,
            context.tr(TranslationKeys.reportIssueDate),
            dateFormatter.format(widget.purchase.purchasedAt),
          ),
          _buildDetailRow(
            palette,
            context.tr(TranslationKeys.reportIssuePaymentId),
            widget.purchase.paymentId,
            isMonospace: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    ReaderPalette palette,
    String label,
    String value, {
    bool isMonospace = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: AppFonts.inter(fontSize: 13, color: palette.muted),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: AppFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: palette.text,
              ).copyWith(
                fontFamily: isMonospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueTypeDropdown(ReaderPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(palette, context.tr(TranslationKeys.reportIssueType)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: BoxDecoration(
            color: palette.raised,
            border: Border.all(color: palette.hairline),
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<PurchaseIssueType>(
              value: _selectedIssueType,
              dropdownColor: palette.card,
              borderRadius: BorderRadius.circular(14),
              iconEnabledColor: palette.muted,
              style: AppFonts.inter(fontSize: 14, color: palette.text),
              isExpanded: true,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedIssueType = value);
                  context
                      .read<PurchaseIssueBloc>()
                      .add(IssueTypeChanged(issueType: value));
                }
              },
              items: PurchaseIssueType.values
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(
                          context.tr(
                            TranslationKeys.reportIssueTypeLabel(type.value),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionInput(ReaderPalette palette) {
    final charCount = _descriptionController.text.length;
    final isValid = charCount >= _minChars && charCount <= _maxChars;

    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _sectionLabel(
                palette,
                context.tr(TranslationKeys.reportIssueDescription),
              ),
            ),
            Text(
              '$charCount/$_maxChars',
              style: AppFonts.inter(
                fontSize: 12,
                color:
                    isValid || charCount == 0 ? palette.dim : AppColors.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          maxLength: _maxChars,
          style: AppFonts.inter(fontSize: 14, color: palette.text),
          cursorColor: palette.accentIcon,
          onChanged: (value) {
            setState(() {}); // Update character count
            context
                .read<PurchaseIssueBloc>()
                .add(DescriptionChanged(description: value));
          },
          decoration: InputDecoration(
            hintText: context.tr(TranslationKeys.reportIssueDescriptionHint),
            hintMaxLines: 3,
            hintStyle: AppFonts.inter(fontSize: 14, color: palette.dim),
            counterText: '',
            filled: true,
            fillColor: palette.raised,
            contentPadding: const EdgeInsets.all(14),
            border: border(palette.hairline),
            enabledBorder: border(palette.hairline),
            focusedBorder: border(palette.accentIcon),
          ),
        ),
        if (charCount > 0 && charCount < _minChars)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              context.tr(TranslationKeys.reportIssueDescriptionTooShort),
              style: AppFonts.inter(fontSize: 12, color: AppColors.error),
            ),
          ),
      ],
    );
  }

  Widget _buildScreenshotSection(
    ReaderPalette palette,
    PurchaseIssueState state,
  ) {
    final formState = state is PurchaseIssueFormReady ? state : null;
    final screenshots = formState?.screenshotUrls ?? [];
    final isUploading = formState?.isUploadingScreenshot ?? false;
    final canAdd = (formState?.canAddScreenshot ?? true) && !isUploading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _sectionLabel(
                palette,
                context.tr(TranslationKeys.reportIssueScreenshots),
              ),
            ),
            Text(
              '${screenshots.length}/3',
              style: AppFonts.inter(fontSize: 12, color: palette.dim),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...screenshots.asMap().entries.map((entry) {
              return _buildScreenshotThumbnail(
                palette,
                entry.key,
                entry.value,
              );
            }),
            if (canAdd || isUploading)
              _buildAddScreenshotButton(palette, isUploading),
          ],
        ),
      ],
    );
  }

  Widget _buildScreenshotThumbnail(
    ReaderPalette palette,
    int index,
    String url,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: palette.raised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.hairline),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              cacheWidth: 240,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.image_outlined,
                  color: palette.accentIcon,
                  size: 32,
                );
              },
            ),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: () {
              context
                  .read<PurchaseIssueBloc>()
                  .add(RemoveScreenshot(index: index));
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddScreenshotButton(ReaderPalette palette, bool isUploading) {
    return Material(
      color: palette.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.outline),
      ),
      child: InkWell(
        onTap: isUploading ? null : _pickImage,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: SizedBox(
          width: 80,
          height: 80,
          child: isUploading
              ? Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.gold,
                    ),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: palette.accentIcon,
                      size: 26,
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        context.tr(TranslationKeys.reportIssueAddScreenshot),
                        textAlign: TextAlign.center,
                        style: AppFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: palette.accentIcon,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    if (!kIsWeb) {
      showAppSnackBar(
        context,
        context.tr(TranslationKeys.reportIssueUploadWebOnly),
      );
      return;
    }

    final result = await IssueImagePicker.pickImage();
    if (result == null) return;

    if (result.containsKey('error')) {
      if (mounted) {
        showAppSnackBar(
          context,
          result['error'] as String,
          tone: AppSnackTone.error,
        );
      }
      return;
    }

    final data = result['data'] as Uint8List;
    final name = result['name'] as String;
    final type = result['type'] as String;

    if (mounted) {
      context.read<PurchaseIssueBloc>().add(
            UploadScreenshotRequested(
              fileName: name,
              fileBytes: data,
              mimeType: type,
            ),
          );
    }
  }

  Widget _buildSubmitButton(ReaderPalette palette, PurchaseIssueState state) {
    final isSubmitting = state is PurchaseIssueSubmitting;
    final isValid = _descriptionController.text.trim().length >= _minChars;
    final label = context.tr(TranslationKeys.reportIssueSubmit);

    if (!isSubmitting) {
      return PopupPrimaryButton(
        label: label,
        onPressed: isValid
            ? () => context
                .read<PurchaseIssueBloc>()
                .add(const SubmitPurchaseIssueRequested())
            : null,
      );
    }

    // Same pill, holding a spinner while the report is sent.
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(
          disabledBackgroundColor: palette.ctaFill.withValues(alpha: 0.6),
          minimumSize: const Size.fromHeight(50),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: Semantics(
          label: label,
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.ctaInk,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows [ReportIssueBottomSheet] for [purchase] above the floating dock.
void showReportIssueBottomSheet(
    BuildContext context, PurchaseHistory purchase) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (context) {
      return BlocProvider(
        create: (context) => sl<PurchaseIssueBloc>()
          ..add(InitializePurchaseIssueForm(
            purchaseId: purchase.id,
            paymentId: purchase.paymentId,
            orderId: purchase.orderId,
            tokenAmount: purchase.tokenAmount,
            costRupees: purchase.costRupees,
            purchasedAt: purchase.purchasedAt,
          )),
        child: ReportIssueBottomSheet(purchase: purchase),
      );
    },
  );
}
