import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/fellowship_entity.dart';
import '../../domain/repositories/community_repository.dart';

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

  /// The caller's fellowship memberships — the user picks from these.
  final List<FellowshipEntity> fellowships;

  /// Pre-filled content to post. When provided, the message input field is
  /// hidden and this value is used directly as the post content.
  final String? content;

  const ShareGuideSheet({
    required this.studyGuideId,
    required this.guideTitle,
    required this.guideInputType,
    required this.guideLanguage,
    required this.fellowships,
    this.content,
    super.key,
  });

  @override
  State<ShareGuideSheet> createState() => _ShareGuideSheetState();
}

class _ShareGuideSheetState extends State<ShareGuideSheet> {
  final _messageController = TextEditingController();

  /// IDs of the fellowships the user has checked.
  final Set<String> _selectedIds = {};

  bool _submitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _studyTypeLabel(String inputType) {
    switch (inputType) {
      case 'topic':
        return 'Topic study';
      case 'scripture':
      default:
        return 'Verse study';
    }
  }

  String _languageLabel(String lang) {
    switch (lang) {
      case 'hi':
        return 'Hindi';
      case 'ml':
        return 'Malayalam';
      case 'en':
      default:
        return 'English';
    }
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
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
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
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _DragHandle(),
            _SheetTitle(),
            const SizedBox(height: 20),
            _GuidePreviewCard(
              title: widget.guideTitle,
              typeLabel: _studyTypeLabel(widget.guideInputType),
              languageLabel: _languageLabel(widget.guideLanguage),
            ),
            const SizedBox(height: 20),
            _SectionLabel(
              text: 'Share to fellowship',
              color: context.appTextSecondary,
            ),
            const SizedBox(height: 8),
            if (widget.fellowships.isEmpty)
              _EmptyFellowshipsNotice()
            else
              _FellowshipList(
                fellowships: widget.fellowships,
                selectedIds: _selectedIds,
                onToggle: (id) => setState(() {
                  if (_selectedIds.contains(id)) {
                    _selectedIds.remove(id);
                  } else {
                    _selectedIds.add(id);
                  }
                }),
              ),
            if (widget.content == null) ...[
              const SizedBox(height: 16),
              _MessageField(controller: _messageController),
            ],
            const SizedBox(height: 24),
            _ShareButton(
              selectedCount: _selectedIds.length,
              submitting: _submitting,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: context.appBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Share Guide',
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: context.appTextPrimary,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _SectionLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

/// Read-only card summarising the guide being shared.
class _GuidePreviewCard extends StatelessWidget {
  final String title;
  final String typeLabel;
  final String languageLabel;

  const _GuidePreviewCard({
    required this.title,
    required this.typeLabel,
    required this.languageLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _MetaChip(label: typeLabel),
                    const SizedBox(width: 6),
                    _MetaChip(label: languageLabel),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: context.appSurfaceVariant,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.appBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: context.appTextSecondary,
        ),
      ),
    );
  }
}

class _EmptyFellowshipsNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appInputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Center(
        child: Text(
          "You don't belong to any fellowship yet.",
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: context.appTextSecondary,
          ),
        ),
      ),
    );
  }
}

class _FellowshipList extends StatelessWidget {
  final List<FellowshipEntity> fellowships;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  const _FellowshipList({
    required this.fellowships,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appInputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        children: List.generate(fellowships.length, (index) {
          final fellowship = fellowships[index];
          final isSelected = selectedIds.contains(fellowship.id);
          final isLast = index == fellowships.length - 1;

          return Column(
            children: [
              _FellowshipRow(
                fellowship: fellowship,
                isSelected: isSelected,
                onToggle: () => onToggle(fellowship.id),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: context.appDivider,
                  indent: 16,
                  endIndent: 16,
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _FellowshipRow extends StatelessWidget {
  final FellowshipEntity fellowship;
  final bool isSelected;
  final VoidCallback onToggle;

  const _FellowshipRow({
    required this.fellowship,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.brandPrimary : Colors.transparent,
                border: Border.all(
                  color:
                      isSelected ? AppColors.brandPrimary : context.appBorder,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fellowship.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${fellowship.memberCount} '
                    '${fellowship.memberCount == 1 ? 'member' : 'members'}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.brandPrimary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageField extends StatelessWidget {
  final TextEditingController controller;

  const _MessageField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: 3,
      maxLength: 500,
      decoration: InputDecoration(
        labelText: 'Add a message (optional)',
        hintText: "What's on your heart?",
        filled: true,
        fillColor: context.appInputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.appBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandPrimary, width: 2),
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final int selectedCount;
  final bool submitting;
  final VoidCallback onSubmit;

  const _ShareButton({
    required this.selectedCount,
    required this.submitting,
    required this.onSubmit,
  });

  String get _label {
    if (selectedCount == 0) return 'Select a fellowship';
    if (selectedCount == 1) return 'Share to 1 Fellowship';
    return 'Share to $selectedCount Fellowships';
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = selectedCount > 0 && !submitting;

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isEnabled ? AppColors.primaryGradient : null,
          color: isEnabled ? null : context.appBorder,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton(
          onPressed: isEnabled ? onSubmit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isEnabled ? Colors.white : context.appTextTertiary,
                  ),
                ),
        ),
      ),
    );
  }
}
