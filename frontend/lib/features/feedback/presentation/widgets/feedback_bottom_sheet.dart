import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../bloc/feedback_bloc.dart';
import '../bloc/feedback_event.dart';
import '../bloc/feedback_state.dart';
import '../utils/user_context_helper.dart';

/// Bottom sheet widget for collecting general feedback
class FeedbackBottomSheet extends StatefulWidget {
  const FeedbackBottomSheet({super.key});

  @override
  State<FeedbackBottomSheet> createState() => _FeedbackBottomSheetState();
}

class _FeedbackBottomSheetState extends State<FeedbackBottomSheet> {
  final TextEditingController _messageController = TextEditingController();
  bool _wasHelpful = true;
  String _selectedCategory = 'general';

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: BlocConsumer<FeedbackBloc, FeedbackState>(
        listener: (context, state) {
          if (state is FeedbackSubmitSuccess) {
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
            // Close the bottom sheet after a brief delay
            Future.delayed(const Duration(milliseconds: 500), () {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            });
            // Reset the state for future use
            context.read<FeedbackBloc>().add(const ResetFeedbackState());
          } else if (state is FeedbackSubmitFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.errorColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHandle(colorScheme),
              const SizedBox(height: 24),
              _buildHeader(colorScheme),
              const SizedBox(height: 24),
              _buildHelpfulToggle(colorScheme),
              const SizedBox(height: 16),
              _buildCategoryDropdown(theme),
              const SizedBox(height: 16),
              _buildMessageInput(theme),
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
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
          Text(
            context.tr(TranslationKeys.feedbackSendFeedback),
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(TranslationKeys.feedbackSubtitle),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      );

  Widget _buildHelpfulToggle(ColorScheme colorScheme) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              _wasHelpful ? Icons.thumb_up : Icons.thumb_down,
              color: colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              context.tr(TranslationKeys.feedbackIsHelpful),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.primary,
              ),
            ),
            const Spacer(),
            Switch(
              value: _wasHelpful,
              onChanged: (value) => setState(() => _wasHelpful = value),
              activeColor: colorScheme.primary,
            ),
          ],
        ),
      );

  Widget _buildCategoryDropdown(ThemeData theme) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedCategory,
            dropdownColor: theme.colorScheme.surface,
            style: theme.textTheme.bodyMedium,
            onChanged: (value) =>
                setState(() => _selectedCategory = value ?? 'general'),
            items: [
              DropdownMenuItem(
                  value: 'general',
                  child: Text(
                      context.tr(TranslationKeys.feedbackCategoryGeneral))),
              DropdownMenuItem(
                  value: 'content',
                  child: Text(
                      context.tr(TranslationKeys.feedbackCategoryContent))),
              DropdownMenuItem(
                  value: 'usability',
                  child: Text(
                      context.tr(TranslationKeys.feedbackCategoryUsability))),
              DropdownMenuItem(
                  value: 'technical',
                  child: Text(
                      context.tr(TranslationKeys.feedbackCategoryTechnical))),
              DropdownMenuItem(
                  value: 'suggestion',
                  child: Text(
                      context.tr(TranslationKeys.feedbackCategorySuggestion))),
            ],
          ),
        ),
      );

  Widget _buildMessageInput(ThemeData theme) => TextField(
        controller: _messageController,
        maxLines: 4,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: context.tr(TranslationKeys.feedbackHintText),
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
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
      );

  Widget _buildSubmitButton() => SizedBox(
        width: double.infinity,
        child: BlocBuilder<FeedbackBloc, FeedbackState>(
          builder: (context, state) {
            final isSubmitting = state is FeedbackSubmitting;

            return ElevatedButton(
              onPressed: isSubmitting ? null : _submitFeedback,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                      context.tr(TranslationKeys.feedbackButtonSend),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            );
          },
        ),
      );

  Future<void> _submitFeedback() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(TranslationKeys.feedbackEmptyMessage)),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final userContext = await UserContextHelper.getCurrentUserContext();

      context.read<FeedbackBloc>().add(
            SubmitGeneralFeedbackRequested(
              wasHelpful: _wasHelpful,
              message: _messageController.text.trim(),
              category: _selectedCategory,
              userContext: userContext,
            ),
          );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(TranslationKeys.feedbackSubmitError)),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// Helper function to show feedback bottom sheet
void showFeedbackBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return BlocProvider(
        create: (context) => sl<FeedbackBloc>(),
        child: const FeedbackBottomSheet(),
      );
    },
  );
}
