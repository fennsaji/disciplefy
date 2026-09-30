import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_buttons.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_text_field.dart';

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
    final palette = ReaderPalette.of(context);
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
      // The sheet is shown on a transparent background, so it paints its
      // own card surface.
      child: Container(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: palette.hairline)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.reportTitle,
                    style: AppFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // The label sits above the field: as a floating label it
                  // is single-line and cut off in Hindi and Malayalam.
                  Text(
                    l10n.reportReasonLabel,
                    style: AppFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _reasonController,
                    maxLength: 500,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppFonts.inter(fontSize: 15, color: palette.text),
                    decoration: communityInputDecoration(
                      context,
                      hintText: l10n.reportReasonHint,
                      // As many lines as the field, so the hint never cuts.
                      hintMaxLines: 4,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 5) {
                        return context.tr(TranslationKeys
                            .communityFellowshipReportReasonShort);
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
                      return Center(
                        child: CommunityCtaPill(
                          label: l10n.reportSubmit,
                          icon: Icons.flag_outlined,
                          loading: loading,
                          onPressed: _submit,
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
