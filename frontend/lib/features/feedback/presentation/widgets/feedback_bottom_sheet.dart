import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:disciplefy_bible_study/features/feedback/presentation/bloc/feedback_event.dart';
import 'package:disciplefy_bible_study/features/feedback/presentation/bloc/feedback_state.dart';
import 'package:disciplefy_bible_study/features/feedback/presentation/utils/user_context_helper.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheet.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

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

  static const List<(String, String)> _categories = [
    ('general', TranslationKeys.feedbackCategoryGeneral),
    ('bug_report', TranslationKeys.feedbackCategoryBugReport),
    ('feature_request', TranslationKeys.feedbackCategoryFeatureRequest),
    ('study_guide', TranslationKeys.feedbackCategoryStudyGuide),
    ('memory_verse', TranslationKeys.feedbackCategoryMemoryVerse),
    ('content_feedback', TranslationKeys.feedbackCategoryContentFeedback),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FeedbackBloc, FeedbackState>(
      listener: (context, state) {
        if (state is FeedbackSubmitSuccess) {
          // Show success message
          showAppSnackBar(context, state.message, tone: AppSnackTone.success);
          // Close the bottom sheet after a brief delay
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          });
          // Reset the state for future use
          context.read<FeedbackBloc>().add(const ResetFeedbackState());
        } else if (state is FeedbackSubmitFailure) {
          showAppSnackBar(
            context,
            context.tr(TranslationKeys.commonErrorTryAgain),
            tone: AppSnackTone.error,
          );
        }
      },
      builder: (context, state) => SettingsSheetFrame(
        title: context.tr(TranslationKeys.feedbackSendFeedback),
        description: context.tr(TranslationKeys.feedbackSubtitle),
        avoidKeyboard: true,
        children: [
          _buildHelpfulToggle(),
          SettingsSectionLabel(context.tr(TranslationKeys.feedbackTopic)),
          _buildCategoryChips(),
          const SizedBox(height: 16),
          _buildMessageInput(),
          const SizedBox(height: 20),
          _buildSubmitButton(state),
        ],
      ),
    );
  }

  Widget _buildHelpfulToggle() {
    final palette = ReaderPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.isDark ? palette.raised : palette.page,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr(TranslationKeys.feedbackIsHelpful),
            style: AppFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HelpfulOption(
                  icon: Icons.thumb_up_outlined,
                  label: context.tr(TranslationKeys.feedbackYes),
                  selected: _wasHelpful,
                  onTap: () => setState(() => _wasHelpful = true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HelpfulOption(
                  icon: Icons.thumb_down_outlined,
                  label: context.tr(TranslationKeys.feedbackNotYet),
                  selected: !_wasHelpful,
                  onTap: () => setState(() => _wasHelpful = false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (value, key) in _categories)
            _CategoryChip(
              label: context.tr(key),
              selected: _selectedCategory == value,
              onTap: () => setState(() => _selectedCategory = value),
            ),
        ],
      );

  Widget _buildMessageInput() {
    final palette = ReaderPalette.of(context);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: color, width: width),
        );
    return TextField(
      controller: _messageController,
      minLines: 4,
      maxLines: 6,
      style: AppFonts.inter(fontSize: 15, color: palette.text, height: 1.45),
      cursorColor: palette.accentIcon,
      decoration: InputDecoration(
        hintText: context.tr(TranslationKeys.feedbackHintText),
        hintStyle: AppFonts.inter(fontSize: 15, color: palette.dim),
        filled: true,
        fillColor: palette.isDark ? palette.raised : palette.card,
        contentPadding: const EdgeInsets.all(16),
        border: border(palette.outline),
        enabledBorder: border(palette.outline),
        focusedBorder: border(palette.accentIcon, 1.5),
      ),
    );
  }

  Widget _buildSubmitButton(FeedbackState state) => SizedBox(
        width: double.infinity,
        child: SettingsButton(
          label: context.tr(TranslationKeys.feedbackButtonSend),
          icon: Icons.send_outlined,
          height: 52,
          loading: state is FeedbackSubmitting,
          onPressed: _submitFeedback,
        ),
      );

  Future<void> _submitFeedback() async {
    if (_messageController.text.trim().isEmpty) {
      showAppSnackBar(
        context,
        context.tr(TranslationKeys.feedbackEmptyMessage),
        tone: AppSnackTone.warning,
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
      showAppSnackBar(
        context,
        context.tr(TranslationKeys.feedbackSubmitError),
        tone: AppSnackTone.error,
      );
    }
  }
}

/// Helper function to show feedback bottom sheet
void showFeedbackBottomSheet(BuildContext context) {
  showSettingsSheet<void>(
    context: context,
    builder: (context) {
      return BlocProvider(
        create: (context) => sl<FeedbackBloc>(),
        child: const FeedbackBottomSheet(),
      );
    },
  );
}

/// "Yes" / "Not yet" answer card.
class _HelpfulOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HelpfulOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final ink = selected ? palette.accentIcon : palette.muted;
    final fill = selected
        ? settingsPrimaryFill(context)
            .withValues(alpha: palette.isDark ? 0.18 : 0.12)
        : (palette.isDark ? palette.card : palette.raised);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? settingsPrimaryFill(context) : Colors.transparent,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: ink),
                const SizedBox(width: 8),
                // Wraps (never cut) for long hi/ml answers at 320pt.
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Topic chip: ink (light) / white (dark) when selected.
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final Color fill;
    final Color ink;
    if (selected) {
      fill = palette.ctaFill;
      ink = palette.ctaInk;
    } else {
      fill = palette.isDark ? palette.raised : palette.card;
      ink = palette.muted;
    }
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: fill,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? Colors.transparent : palette.outline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              label,
              style: AppFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
