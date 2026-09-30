import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart'
    as auth_states;
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/guide_share_summary.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_form_parts.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_top_bars.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_card_parts.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/member_avatar.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheet.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_mode_labels.dart';
import 'package:disciplefy_bible_study/shared/widgets/sheet_scroll_view.dart';

/// A modal bottom sheet that lets users share a study guide to one or more of
/// their fellowships with an optional personal message.
///
/// On a successful submission the sheet pops with `true` so the caller can
/// react (e.g. show a "Shared!" snackbar).
class ShareGuideSheet extends StatefulWidget {
  /// The primary key of the study guide being shared.
  final String studyGuideId;

  /// Human-readable title of the guide.
  final String guideTitle;

  /// `'scripture'` or `'topic'`.
  final String guideInputType;

  /// `'en'`, `'hi'`, or `'ml'`.
  final String guideLanguage;

  /// Study mode the guide was generated in (`'standard'`, `'deep'`…), or
  /// null when unknown. Shown in the preview and stored on the post.
  final String? guideStudyMode;

  /// The guide's summary section as the guide screen has it; the first
  /// sentence or two go on the post as its preview.
  final String? guideSummary;

  /// The caller's fellowship memberships — the user picks from these.
  final List<FellowshipEntity> fellowships;

  /// Pre-filled content to post. When provided, the message input field is
  /// hidden and this value is used directly as the post content.
  final String? content;

  /// Fellowships checked when the sheet opens (e.g. the ones picked on the
  /// study guide). Empty: none checked.
  final Set<String> initialSelectedIds;

  const ShareGuideSheet({
    required this.studyGuideId,
    required this.guideTitle,
    required this.guideInputType,
    required this.guideLanguage,
    this.guideStudyMode,
    this.guideSummary,
    required this.fellowships,
    this.content,
    this.initialSelectedIds = const {},
    super.key,
  });

  @override
  State<ShareGuideSheet> createState() => _ShareGuideSheetState();
}

class _ShareGuideSheetState extends State<ShareGuideSheet> {
  final _messageController = TextEditingController();

  /// IDs of the fellowships the user has checked.
  late final Set<String> _selectedIds = {...widget.initialSelectedIds};

  bool _submitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _studyTypeLabel(BuildContext context, String inputType) {
    switch (inputType) {
      case 'topic':
        return context.tr(TranslationKeys.communityTopicStudyLabel);
      case 'scripture':
      default:
        return context.tr(TranslationKeys.communityVerseStudyLabel);
    }
  }

  /// Native language names, so the chip reads the same in every app locale.
  String _languageLabel(String lang) {
    switch (lang) {
      case 'hi':
        return 'हिन्दी';
      case 'ml':
        return 'മലയാളം';
      case 'en':
      default:
        return 'English';
    }
  }

  /// "Standard study guide · 8 min" when the study mode is known, otherwise
  /// "{Verse/Topic study} · {language}".
  String _previewSubtitle(BuildContext context) {
    final mode = studyModeFromString(widget.guideStudyMode);
    if (mode != null) {
      final name = context.tr(TranslationKeys.communityPostModeStudyGuide,
          {'mode': mode.localizedShortName(context)});
      return '$name · ${mode.localizedDuration(context)}';
    }
    return '${_studyTypeLabel(context, widget.guideInputType)} · '
        '${_languageLabel(widget.guideLanguage)}';
  }

  /// Signed-in user's id, for "(you)" on fellowships they mentor.
  String? _currentUserId(BuildContext context) {
    try {
      final state = context.read<AuthBloc>().state;
      if (state is auth_states.AuthenticatedState) return state.userId;
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------------------
  // Submission
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (_selectedIds.isEmpty || _submitting) return;

    setState(() => _submitting = true);

    final repo = sl<CommunityRepository>();
    final message = widget.content ?? _messageController.text.trim();
    final selectedFellowships =
        widget.fellowships.where((f) => _selectedIds.contains(f.id)).toList();
    final studyMode = studyModeFromString(widget.guideStudyMode)?.name;
    final summary = condenseGuideSummary(widget.guideSummary);

    bool hasError = false;

    for (final fellowship in selectedFellowships) {
      final result = await repo.createPost(
        fellowshipId: fellowship.id,
        content: message,
        postType: 'shared_guide',
        studyGuideId: widget.studyGuideId,
        guideTitle: widget.guideTitle,
        guideInputType: widget.guideInputType,
        guideLanguage: widget.guideLanguage,
        guideStudyMode: studyMode,
        guideSummary: summary,
      );

      result.fold(
        (failure) {
          hasError = true;
        },
        (_) {},
      );
    }

    if (!mounted) return;

    setState(() => _submitting = false);

    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(TranslationKeys.commonErrorTryAgain)),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    Navigator.of(context).pop(true);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final currentUserId = _currentUserId(context);
    final selectedCount = _selectedIds.length;
    final shareLabel = selectedCount == 0
        ? context.tr(TranslationKeys.communityPagesShareSelect)
        : selectedCount == 1
            ? context.tr(TranslationKeys.communityPagesShareToOne)
            : context.tr(TranslationKeys.communityPagesShareToMany,
                {'count': selectedCount});

    return Container(
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
        child: SheetScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: palette.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                context.tr(TranslationKeys.communityPagesShareTitle),
                style: AppFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 18),
              _GuidePreviewCard(
                title: widget.guideTitle,
                subtitle: _previewSubtitle(context),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CommunitySectionLabel(
                  context.tr(TranslationKeys.communityPagesShareTo),
                  color: palette.muted,
                ),
              ),
              if (widget.fellowships.isEmpty)
                const _EmptyFellowshipsNotice()
              else
                SettingsSheetGroup(
                  children: [
                    for (final fellowship in widget.fellowships)
                      _FellowshipRow(
                        fellowship: fellowship,
                        currentUserId: currentUserId,
                        isSelected: _selectedIds.contains(fellowship.id),
                        onToggle: () => setState(() {
                          if (!_selectedIds.remove(fellowship.id)) {
                            _selectedIds.add(fellowship.id);
                          }
                        }),
                      ),
                  ],
                ),
              if (widget.content == null) ...[
                const SizedBox(height: 18),
                CommunityFieldLabel(context
                    .tr(TranslationKeys.communityPagesShareMessageLabel)),
                TextFormField(
                  controller: _messageController,
                  maxLines: 3,
                  maxLength: 500,
                  style: communityInputStyle(context),
                  decoration: communityInputDecoration(
                    context,
                    hintText: context
                        .tr(TranslationKeys.communityPagesShareMessageHint),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              CommunityWideCta(
                label: shareLabel,
                icon: Icons.send_outlined,
                loading: _submitting,
                onPressed: selectedCount > 0 && !_submitting ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Read-only row summarising the guide being shared: book tile, title and
/// a subtitle ("Standard study guide · 8 min").
class _GuidePreviewCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _GuidePreviewCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.isDark ? palette.raised : palette.page,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary
                  .withValues(alpha: palette.isDark ? 0.22 : 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.menu_book_outlined,
                size: 20, color: palette.accentIcon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.inter(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppFonts.inter(
                    fontSize: 13.5,
                    color: palette.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFellowshipsNotice extends StatelessWidget {
  const _EmptyFellowshipsNotice();

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.isDark ? palette.raised : palette.page,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        context.tr(TranslationKeys.communityPagesShareNone),
        textAlign: TextAlign.center,
        style: AppFonts.inter(fontSize: 14, color: palette.muted, height: 1.4),
      ),
    );
  }
}

/// One fellowship to share to: mentor avatar, name, "Mentor: X · N members"
/// and a rounded-square checkbox on the right.
class _FellowshipRow extends StatelessWidget {
  final FellowshipEntity fellowship;
  final String? currentUserId;
  final bool isSelected;
  final VoidCallback onToggle;

  const _FellowshipRow({
    required this.fellowship,
    required this.currentUserId,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final mentor = FellowshipMentorInfo.forFellowship(
      fellowship,
      currentUserId: currentUserId,
    );
    return Semantics(
      checked: isSelected,
      child: InkWell(
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                _MentorAvatar(mentor: mentor, fellowshipName: fellowship.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fellowship.name,
                        style: AppFonts.inter(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fellowshipMentorLine(
                            context, mentor, fellowship.memberCount),
                        style: AppFonts.inter(
                          fontSize: 13,
                          color: palette.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ReaderPalette.selectedFill
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? ReaderPalette.selectedFill
                          : palette.outline,
                      width: 1.6,
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The fellowship mentor's avatar: the Discipler mark for official and
/// Discipler-mentored fellowships, otherwise the mentor's photo or initials
/// (the fellowship's initials when the mentor is unknown).
class _MentorAvatar extends StatelessWidget {
  final FellowshipMentorInfo mentor;
  final String fellowshipName;

  const _MentorAvatar({required this.mentor, required this.fellowshipName});

  @override
  Widget build(BuildContext context) {
    const radius = 16.0;
    if (mentor.isDiscipler) return const DisciplerAvatar(radius: radius);
    final name = mentor.name;
    return MemberAvatar(
      displayName: name != null && name.isNotEmpty ? name : fellowshipName,
      avatarUrl: mentor.avatarUrl,
      radius: radius,
    );
  }
}
