import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../tokens/domain/entities/purchase_history.dart';
import '../../domain/entities/purchase_issue_entity.dart';
import '../bloc/purchase_issue_bloc.dart';
import '../bloc/purchase_issue_event.dart';
import '../bloc/purchase_issue_state.dart';

// Conditional import for web image picker
import '../utils/issue_image_picker_stub.dart'
    if (dart.library.html) '../utils/issue_image_picker_web.dart';

/// Bottom sheet widget for reporting purchase issues
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

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormatter = DateFormat('MMM dd, yyyy • hh:mm a');

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: BlocConsumer<PurchaseIssueBloc, PurchaseIssueState>(
        listener: (context, state) {
          if (state is PurchaseIssueSubmitSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
            Future.delayed(const Duration(milliseconds: 500), () {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            });
          } else if (state is PurchaseIssueSubmitFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.errorColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is PurchaseIssueFormReady &&
              state.uploadError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.uploadError!),
                backgroundColor: AppTheme.errorColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHandle(colorScheme),
                const SizedBox(height: 20),
                _buildHeader(colorScheme),
                const SizedBox(height: 20),
                _buildTransactionDetails(theme, dateFormatter),
                const SizedBox(height: 20),
                _buildIssueTypeDropdown(theme, state),
                const SizedBox(height: 16),
                _buildDescriptionInput(theme, state),
                const SizedBox(height: 16),
                _buildScreenshotSection(theme, state),
                const SizedBox(height: 24),
                _buildSubmitButton(state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHandle(ColorScheme colorScheme) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildHeader(ColorScheme colorScheme) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.report_problem_outlined,
                color: Colors.orange.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Report Issue',
                style: AppFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Describe the issue with your purchase. Our team will review and respond within 24-48 hours.',
            style: AppFonts.inter(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      );

  Widget _buildTransactionDetails(ThemeData theme, DateFormat dateFormatter) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction Details',
            style: AppFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailRow(theme, 'Tokens', '${widget.purchase.tokenAmount}'),
          _buildDetailRow(
            theme,
            'Amount',
            '₹${widget.purchase.costRupees.toStringAsFixed(2)}',
          ),
          _buildDetailRow(
            theme,
            'Date',
            dateFormatter.format(widget.purchase.purchasedAt),
          ),
          _buildDetailRow(
            theme,
            'Payment ID',
            widget.purchase.paymentId,
            isMonospace: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    ThemeData theme,
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
            width: 80,
            child: Text(
              label,
              style: AppFonts.inter(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ).copyWith(
                fontFamily: isMonospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueTypeDropdown(ThemeData theme, PurchaseIssueState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Issue Type',
          style: AppFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<PurchaseIssueType>(
              value: _selectedIssueType,
              dropdownColor: theme.colorScheme.surface,
              style: theme.textTheme.bodyMedium,
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
                        child: Text(type.label),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionInput(ThemeData theme, PurchaseIssueState state) {
    final charCount = _descriptionController.text.length;
    final isValid = charCount >= 10 && charCount <= 2000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Description',
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              '$charCount/2000',
              style: AppFonts.inter(
                fontSize: 12,
                color: isValid || charCount == 0
                    ? theme.colorScheme.onSurface.withOpacity(0.5)
                    : AppTheme.errorColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          maxLength: 2000,
          style: theme.textTheme.bodyMedium,
          onChanged: (value) {
            setState(() {}); // Update character count
            context
                .read<PurchaseIssueBloc>()
                .add(DescriptionChanged(description: value));
          },
          decoration: InputDecoration(
            hintText:
                'Please describe the issue in detail (minimum 10 characters)',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
          ),
        ),
        if (charCount > 0 && charCount < 10)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Please enter at least 10 characters',
              style: AppFonts.inter(
                fontSize: 12,
                color: AppTheme.errorColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScreenshotSection(ThemeData theme, PurchaseIssueState state) {
    final formState = state is PurchaseIssueFormReady ? state : null;
    final screenshots = formState?.screenshotUrls ?? [];
    final isUploading = formState?.isUploadingScreenshot ?? false;
    final canAdd = (formState?.canAddScreenshot ?? true) && !isUploading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Screenshots (optional)',
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              '${screenshots.length}/3',
              style: AppFonts.inter(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
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
                theme,
                entry.key,
                entry.value,
              );
            }),
            if (canAdd) _buildAddScreenshotButton(theme, isUploading),
          ],
        ),
      ],
    );
  }

  Widget _buildScreenshotThumbnail(
    ThemeData theme,
    int index,
    String url,
  ) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.image,
                  color: theme.colorScheme.primary,
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
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
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

  Widget _buildAddScreenshotButton(ThemeData theme, bool isUploading) {
    return GestureDetector(
      onTap: isUploading ? null : _pickImage,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: isUploading
            ? Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add',
                    style: AppFonts.inter(
                      fontSize: 11,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _pickImage() async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image upload is only supported on web'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await IssueImagePicker.pickImage();
    if (result == null) return;

    if (result.containsKey('error')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] as String),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
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

  Widget _buildSubmitButton(PurchaseIssueState state) {
    final isSubmitting = state is PurchaseIssueSubmitting;
    final isValid = _descriptionController.text.trim().length >= 10;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isSubmitting || !isValid
            ? null
            : () {
                context
                    .read<PurchaseIssueBloc>()
                    .add(const SubmitPurchaseIssueRequested());
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          disabledBackgroundColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Submit Report',
                style: AppFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

/// Helper function to show report issue bottom sheet
void showReportIssueBottomSheet(
    BuildContext context, PurchaseHistory purchase) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
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
