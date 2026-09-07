import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/fellowship_comment_entity.dart';
import '../../domain/entities/fellowship_post_entity.dart';
import '../bloc/fellowship_feed/fellowship_feed_bloc.dart';
import '../bloc/fellowship_feed/fellowship_feed_event.dart';
import '../bloc/fellowship_feed/fellowship_feed_state.dart';
import '../utils/auth_helpers.dart';
import '../utils/feed_sort.dart';
import '../utils/markdown_text.dart';
import '../utils/mention_text.dart';
import '../utils/share_helpers.dart';
import '../widgets/block_user_dialog.dart';
import '../widgets/discipler_badges.dart';
import '../widgets/fellowship_post_card.dart';
import '../widgets/mention_sheet.dart';
import '../widgets/study_guide_chip.dart';
import 'package:disciplefy_bible_study/core/theme/contrast.dart';

/// Reports a post or comment to the fellowship's mentors.
///
/// Shared by the feed and the fellowship home preview so both surfaces offer
/// the same reporting flow.
class FellowshipReportSheet extends StatefulWidget {
  final String fellowshipId;
  final String contentType; // 'post' or 'comment'
  final String contentId;

  const FellowshipReportSheet({
    required this.fellowshipId,
    required this.contentType,
    required this.contentId,
    super.key,
  });

  @override
  State<FellowshipReportSheet> createState() => FellowshipReportSheetState();
}

class FellowshipReportSheetState extends State<FellowshipReportSheet> {
  final TextEditingController _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<FellowshipFeedBloc>().add(
          FellowshipReportRequested(
            fellowshipId: widget.fellowshipId,
            contentType: widget.contentType,
            contentId: widget.contentId,
            reason: _reasonController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<FellowshipFeedBloc, FellowshipFeedState>(
      listenWhen: (prev, curr) => prev.reportStatus != curr.reportStatus,
      listener: (context, state) {
        if (state.reportStatus == FellowshipReportStatus.success) {
          Navigator.of(context).maybePop();
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(l10n.reportSuccess),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              ),
            );
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.appBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.reportTitle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reasonController,
                    maxLength: 500,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: context.appTextPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.reportReasonLabel,
                      hintText: l10n.reportReasonHint,
                      filled: true,
                      fillColor: context.appInputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 5) {
                        return 'Please provide at least 5 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
                    buildWhen: (prev, curr) =>
                        prev.reportStatus != curr.reportStatus,
                    builder: (context, state) {
                      final loading =
                          state.reportStatus == FellowshipReportStatus.loading;
                      return SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.appInteractive,
                            foregroundColor: AppColors.onGradient,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onGradient,
                                  ),
                                )
                              : Text(
                                  l10n.reportSubmit,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
