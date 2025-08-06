import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
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
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHandle(),
            const SizedBox(height: 24),
            _buildHeader(),
            const SizedBox(height: 24),
            _buildHelpfulToggle(),
            const SizedBox(height: 16),
            _buildCategoryDropdown(),
            const SizedBox(height: 16),
            _buildMessageInput(),
            const SizedBox(height: 24),
            _buildSubmitButton(),
          ],
        ),
      );

  Widget _buildHandle() => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.onSurfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildHeader() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Send Feedback',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Help us improve Disciplefy by sharing your thoughts',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      );

  Widget _buildHelpfulToggle() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              _wasHelpful ? Icons.thumb_up : Icons.thumb_down,
              color: AppTheme.primaryColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Is the app helpful?',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryColor,
              ),
            ),
            const Spacer(),
            Switch(
              value: _wasHelpful,
              onChanged: (value) => setState(() => _wasHelpful = value),
              activeColor: AppTheme.primaryColor,
            ),
          ],
        ),
      );

  Widget _buildCategoryDropdown() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.onSurfaceVariant.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedCategory,
            onChanged: (value) =>
                setState(() => _selectedCategory = value ?? 'general'),
            items: const [
              DropdownMenuItem(
                  value: 'general', child: Text('General Feedback')),
              DropdownMenuItem(
                  value: 'content', child: Text('Content & Study Guides')),
              DropdownMenuItem(
                  value: 'usability', child: Text('App Usability')),
              DropdownMenuItem(
                  value: 'technical', child: Text('Technical Issues')),
              DropdownMenuItem(
                  value: 'suggestion', child: Text('Feature Suggestion')),
            ],
          ),
        ),
      );

  Widget _buildMessageInput() => TextField(
        controller: _messageController,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: 'Tell us what you think...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppTheme.onSurfaceVariant.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primaryColor),
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
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
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
                      'Send Feedback',
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
        const SnackBar(
          content: Text('Please enter a message'),
          backgroundColor: AppTheme.errorColor,
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
        const SnackBar(
          content:
              Text('Failed to prepare feedback submission. Please try again.'),
          backgroundColor: AppTheme.errorColor,
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
    builder: (context) => const FeedbackBottomSheet(),
  );
}
