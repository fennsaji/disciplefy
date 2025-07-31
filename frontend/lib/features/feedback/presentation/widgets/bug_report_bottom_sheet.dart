import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/feedback_bloc.dart';
import '../bloc/feedback_event.dart';
import '../bloc/feedback_state.dart';
import '../utils/user_context_helper.dart';

/// Bottom sheet widget for collecting bug reports
class BugReportBottomSheet extends StatefulWidget {
  const BugReportBottomSheet({super.key});

  @override
  State<BugReportBottomSheet> createState() => _BugReportBottomSheetState();
}

class _BugReportBottomSheetState extends State<BugReportBottomSheet> {
  final TextEditingController _messageController = TextEditingController();

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
        Row(
          children: [
            const Icon(
              Icons.bug_report,
              color: AppTheme.errorColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Report Issue',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.errorColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Found a bug? Describe what happened and we\'ll fix it',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      ],
    );

  Widget _buildMessageInput() => TextField(
      controller: _messageController,
      maxLines: 5,
      decoration: InputDecoration(
        hintText: 'Describe the issue you encountered...\n\nSteps to reproduce:\n1. \n2. \n3. ',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.onSurfaceVariant.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.errorColor),
        ),
      ),
    );

  Widget _buildSubmitButton() => SizedBox(
      width: double.infinity,
      child: BlocBuilder<FeedbackBloc, FeedbackState>(
        builder: (context, state) {
          final isSubmitting = state is FeedbackSubmitting;
          
          return ElevatedButton(
            onPressed: isSubmitting ? null : _submitBugReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
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
                    'Report Issue',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          );
        },
      ),
    );

  Future<void> _submitBugReport() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe the issue'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    try {
      final userContext = await UserContextHelper.getCurrentUserContext();
      
      context.read<FeedbackBloc>().add(
        SubmitBugReportRequested(
          message: _messageController.text.trim(),
          userContext: userContext,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to prepare bug report submission. Please try again.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}

/// Helper function to show bug report bottom sheet
void showBugReportBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const BugReportBottomSheet(),
  );
}