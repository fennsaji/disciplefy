import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/daily_post_status_entity.dart';
import '../bloc/fellowship_daily_post/fellowship_daily_post_bloc.dart';
import '../bloc/fellowship_daily_post/fellowship_daily_post_event.dart';
import '../bloc/fellowship_daily_post/fellowship_daily_post_state.dart';

/// Mentor controls for the Discipler daily post: when the next post goes out,
/// the schedule (time, skip, pause), the lesson queue, and — when an admin has
/// enabled them — preview, a new teaser, and posting now.
class FellowshipDailyPostScreen extends StatelessWidget {
  final String fellowshipId;

  const FellowshipDailyPostScreen({required this.fellowshipId, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.appScaffold,
      appBar: AppBar(
        backgroundColor: context.appScaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          l10n.dailyPostScreenTitle,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
      ),
      body: BlocConsumer<FellowshipDailyPostBloc, FellowshipDailyPostState>(
        listenWhen: (previous, current) =>
            current.notice != null && current.notice != previous.notice,
        listener: (context, state) => _showNotice(context, state.notice!),
        builder: (context, state) {
          switch (state.status) {
            case FellowshipDailyPostStatus.initial:
            case FellowshipDailyPostStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case FellowshipDailyPostStatus.failure:
              return _LoadError(
                message: state.errorMessage ?? l10n.dailyPostLoadError,
                onRetry: () => context
                    .read<FellowshipDailyPostBloc>()
                    .add(FellowshipDailyPostLoadRequested(fellowshipId)),
              );
            case FellowshipDailyPostStatus.loaded:
              return _DailyPostBody(data: state.data!, saving: state.saving);
          }
        },
      ),
    );
  }

  void _showNotice(BuildContext context, FellowshipDailyPostNotice notice) {
    final l10n = AppLocalizations.of(context)!;
    final String message;
    if (notice.success) {
      message = switch (notice.kind) {
        'preview' => l10n.dailyPostDonePreview,
        'regenerate' => l10n.dailyPostDoneRegenerate,
        'post_now' => l10n.dailyPostDonePostNow,
        'repost' => l10n.dailyPostDoneRepost,
        _ => l10n.dailyPostDoneSchedule,
      };
    } else {
      message = notice.error ?? l10n.dailyPostError;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: notice.success ? AppColors.success : context.appError,
        behavior: SnackBarBehavior.floating,
      ));
  }
}

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

String _dateLabel(BuildContext context, String isoDate, String today) {
  final l10n = AppLocalizations.of(context)!;
  if (isoDate == today) return l10n.dailyPostToday;
  final date = DateTime.tryParse(isoDate);
  final now = DateTime.tryParse(today);
  if (date == null) return isoDate;
  if (now != null && date.difference(now).inDays == 1) {
    return l10n.dailyPostTomorrow;
  }
  return DateFormat.MMMd(Localizations.localeOf(context).languageCode)
      .format(date);
}

String _timeLabel(BuildContext context, String hhmm) {
  final parts = hhmm.split(':');
  final hour = int.tryParse(parts.first);
  final minute = parts.length > 1 ? int.tryParse(parts[1]) : 0;
  if (hour == null || minute == null) return hhmm;
  return DateFormat.jm(Localizations.localeOf(context).languageCode)
      .format(DateTime(2000, 1, 1, hour, minute));
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The pause covers its last day, so posting starts the day after.
String _dayAfter(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  return date == null ? isoDate : _isoDate(date.add(const Duration(days: 1)));
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _DailyPostBody extends StatelessWidget {
  final DailyPostStatusEntity data;
  final bool saving;

  const _DailyPostBody({required this.data, required this.saving});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<FellowshipDailyPostBloc>();

    return RefreshIndicator(
      onRefresh: () async =>
          bloc.add(const FellowshipDailyPostRefreshRequested()),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _NextPostCard(data: data),
          if (data.settings.postNowAllowed) ...[
            const SizedBox(height: 12),
            _PostNowSection(data: data, saving: saving),
          ],
          const SizedBox(height: 28),
          _SectionTitle(
              icon: Icons.schedule_rounded, text: l10n.dailyPostScheduleTitle),
          _ScheduleSection(data: data, saving: saving),
          const SizedBox(height: 28),
          _SectionTitle(
              icon: Icons.format_list_numbered_rounded,
              text: l10n.dailyPostUpNextTitle),
          _UpNextSection(data: data, saving: saving),
          if (data.settings.previewAllowed) ...[
            const SizedBox(height: 28),
            _SectionTitle(
                icon: Icons.visibility_outlined,
                text: l10n.dailyPostPreviewTitle),
            _PreviewSection(data: data, saving: saving),
          ],
          const SizedBox(height: 28),
          _SectionTitle(
              icon: Icons.history_rounded, text: l10n.dailyPostHistoryTitle),
          _HistorySection(data: data, saving: saving),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SectionTitle({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.appTextSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? scheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _WorkingRow extends StatelessWidget {
  const _WorkingRow();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: scheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.dailyPostWorking,
              style: TextStyle(fontSize: 13, color: context.appTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small rounded label, e.g. "Posts next".
class _Pill extends StatelessWidget {
  final String text;

  const _Pill(this.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.primary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Next post
// ---------------------------------------------------------------------------

class _NextPostCard extends StatelessWidget {
  final DailyPostStatusEntity data;

  const _NextPostCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final settings = data.settings;
    final paused = settings.pausedUntil != null &&
        settings.pausedUntil!.compareTo(data.today) >= 0;
    final active = settings.dailyPostOn && !paused;

    final String headline;
    if (!settings.dailyPostOn) {
      headline = l10n.dailyPostOff;
    } else if (paused) {
      headline = l10n.dailyPostPausedUntil(
          _dateLabel(context, settings.pausedUntil!, data.today));
    } else if (data.nextPostDate != null) {
      headline = l10n.dailyPostAtTime(
        _dateLabel(context, data.nextPostDate!, data.today),
        _timeLabel(context, data.nextPostTime ?? settings.time),
      );
    } else {
      headline = l10n.dailyPostNothingNext;
    }

    final nextLesson = data.upcoming.isNotEmpty ? data.upcoming.first : null;
    final secondary =
        TextStyle(fontSize: 13, height: 1.4, color: context.appTextSecondary);

    return _Panel(
      padding: const EdgeInsets.all(18),
      color: active ? scheme.primary.withValues(alpha: 0.06) : null,
      borderColor: active ? scheme.primary.withValues(alpha: 0.25) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: active
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  active ? Icons.event_available_rounded : Icons.pause_rounded,
                  size: 20,
                  color: active ? scheme.onPrimary : context.appTextSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.dailyPostNextTitle, style: secondary)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            headline,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: active ? 22 : 16,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: active ? scheme.primary : context.appTextPrimary,
            ),
          ),
          if (active) ...[
            const SizedBox(height: 6),
            Text(
              nextLesson?.title ?? l10n.dailyPostNothingNext,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: context.appTextPrimary,
              ),
            ),
          ],
          if (data.pathTitle != null || data.lastPost?.topicTitle != null) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 12),
          ],
          if (data.pathTitle != null)
            Text('${l10n.dailyPostPath}: ${data.pathTitle}', style: secondary),
          if (data.lastPost?.topicTitle != null) ...[
            const SizedBox(height: 4),
            Text(
              '${l10n.dailyPostLastPost}: ${data.lastPost!.topicTitle} (${_dateLabel(context, data.lastPost!.postDate, data.today)})',
              style: secondary,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Post now (admin-gated)
// ---------------------------------------------------------------------------

class _PostNowSection extends StatelessWidget {
  final DailyPostStatusEntity data;
  final bool saving;

  const _PostNowSection({required this.data, required this.saving});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final working = data.request('post_now')?.isOpen ?? false;

    if (working) return const _WorkingRow();

    // Once today's post is out there is nothing to press: say so instead of
    // showing a greyed-out button.
    if (data.postedToday) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 18, color: AppColors.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.dailyPostPostedToday,
                style: TextStyle(fontSize: 13, color: context.appTextSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.send_rounded, size: 18),
        label: Text(l10n.dailyPostPostNow),
        onPressed: saving ? null : () => _confirm(context),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<FellowshipDailyPostBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.dailyPostPostNowConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.dailyPostCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.dailyPostPostNow),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      bloc.add(const FellowshipDailyPostActionRequested('post_now'));
    }
  }
}

// ---------------------------------------------------------------------------
// Schedule
// ---------------------------------------------------------------------------

class _ScheduleSection extends StatelessWidget {
  final DailyPostStatusEntity data;
  final bool saving;

  const _ScheduleSection({required this.data, required this.saving});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final bloc = context.read<FellowshipDailyPostBloc>();
    final settings = data.settings;
    // A skip for today no longer applies once today's post has gone out.
    final skipDate = settings.skipDate;
    final skipActive = skipDate != null &&
        (skipDate.compareTo(data.today) > 0 ||
            (skipDate == data.today && !data.postedToday));
    final paused = settings.pausedUntil != null &&
        settings.pausedUntil!.compareTo(data.today) >= 0;

    return _Panel(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n.disciplerDailyToggle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            value: settings.dailyPostOn,
            onChanged: saving
                ? null
                : (v) => bloc
                    .add(FellowshipDailyPostSettingsChanged(dailyPostOn: v)),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 14),
          Text(
            l10n.dailyPostFrequency,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          // Chips like the posting time below, so long labels never wrap
          // inside a segment.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (days, label) in [
                (1, l10n.frequencyDaily),
                (2, l10n.frequencyEveryTwoDays),
                (7, l10n.frequencyWeekly),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: days == settings.frequencyDays,
                  showCheckmark: false,
                  selectedColor: scheme.primary,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: days == settings.frequencyDays
                        ? scheme.onPrimary
                        : context.appTextPrimary,
                  ),
                  onSelected: saving || !settings.dailyPostOn
                      ? null
                      : (_) {
                          if (days != settings.frequencyDays) {
                            bloc.add(FellowshipDailyPostSettingsChanged(
                                frequencyDays: days));
                          }
                        },
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            l10n.dailyPostTimeLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final time in settings.times)
                ChoiceChip(
                  label: Text(_timeLabel(context, time)),
                  selected: time == settings.time,
                  showCheckmark: false,
                  selectedColor: scheme.primary,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: time == settings.time
                        ? scheme.onPrimary
                        : context.appTextPrimary,
                  ),
                  // Kept enabled when selected: a null handler greys the
                  // chosen time out so it reads as unavailable.
                  onSelected: saving
                      ? null
                      : (_) {
                          if (time != settings.time) {
                            bloc.add(
                                FellowshipDailyPostScheduleChanged(time: time));
                          }
                        },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: scheme.outlineVariant),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n.disciplerAdvancesLessons,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(l10n.disciplerAdvancesLessonsSubtitle),
            value: settings.autoAdvance,
            onChanged: saving || !settings.dailyPostOn
                ? null
                : (v) => bloc
                    .add(FellowshipDailyPostSettingsChanged(autoAdvance: v)),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n.dailyPostSkipNext,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(skipActive
                ? l10n
                    .dailyPostSkipped(_dateLabel(context, skipDate, data.today))
                : l10n.dailyPostSkipNextSubtitle),
            value: skipActive,
            onChanged: saving || !settings.dailyPostOn
                ? null
                : (v) =>
                    bloc.add(FellowshipDailyPostScheduleChanged(skipNext: v)),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              paused
                  ? l10n.dailyPostPausedUntil(
                      _dateLabel(context, settings.pausedUntil!, data.today))
                  : l10n.dailyPostPause,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(paused
                ? l10n.dailyPostResumesOn(_dateLabel(
                    context, _dayAfter(settings.pausedUntil!), data.today))
                : l10n.dailyPostPauseSubtitle),
          ),
          // Under the text rather than trailing: in Malayalam a trailing
          // button squeezed the title to one word per line.
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: paused
                ? OutlinedButton.icon(
                    onPressed: saving
                        ? null
                        : () => bloc.add(
                            const FellowshipDailyPostScheduleChanged(
                                clearPause: true)),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(l10n.dailyPostResume),
                  )
                : OutlinedButton.icon(
                    onPressed: saving || !settings.dailyPostOn
                        ? null
                        : () => _pickPauseDate(context),
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(l10n.dailyPostPickDate),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPauseDate(BuildContext context) async {
    final bloc = context.read<FellowshipDailyPostBloc>();
    final today = DateTime.tryParse(data.today) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: today.add(const Duration(days: 1)),
      firstDate: today,
      // Official groups can pause for as long as they need.
      lastDate: today.add(Duration(days: data.settings.noLimits ? 3650 : 90)),
      helpText: AppLocalizations.of(context)!.dailyPostPause,
    );
    if (picked == null) return;
    bloc.add(FellowshipDailyPostScheduleChanged(pausedUntil: _isoDate(picked)));
  }
}

// ---------------------------------------------------------------------------
// Up next
// ---------------------------------------------------------------------------

class _UpNextSection extends StatelessWidget {
  final DailyPostStatusEntity data;
  final bool saving;

  const _UpNextSection({required this.data, required this.saving});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final bloc = context.read<FellowshipDailyPostBloc>();

    if (data.upcoming.isEmpty) {
      return _Panel(
        child: Text(
          l10n.dailyPostUpNextEmpty,
          style: TextStyle(
              fontSize: 14, height: 1.4, color: context.appTextSecondary),
        ),
      );
    }

    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < data.upcoming.length; i++) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == 0
                          ? scheme.primary
                          : scheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${data.upcoming[i].position + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: i == 0 ? scheme.onPrimary : scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.upcoming[i].title,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.35,
                            fontWeight:
                                i == 0 ? FontWeight.w600 : FontWeight.w500,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (i == 0)
                          _Pill(l10n.dailyPostPostsNext)
                        else
                          // Below the title rather than beside it: a long
                          // translated label beside the title squeezed it
                          // to one letter per line.
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: saving
                                ? null
                                : () => bloc.add(
                                    FellowshipDailyPostScheduleChanged(
                                        nextLearningPathTopicId: data
                                            .upcoming[i].learningPathTopicId)),
                            child: Text(l10n.dailyPostPostThisNext),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Preview (admin-gated)
// ---------------------------------------------------------------------------

class _PreviewSection extends StatelessWidget {
  final DailyPostStatusEntity data;
  final bool saving;

  const _PreviewSection({required this.data, required this.saving});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final bloc = context.read<FellowshipDailyPostBloc>();
    final preview = data.preview;
    final working = (data.request('preview')?.isOpen ?? false) ||
        (data.request('regenerate')?.isOpen ?? false);
    final regenerationsLeft = preview?.regenerationsLeft ?? 0;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (working) const _WorkingRow(),
          if (preview != null) ...[
            if (!preview.isCurrent) ...[
              // A gentle amber note, not an error: the preview is only out of
              // date, and previewing again fixes it.
              Builder(builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final noteBackground =
                    isDark ? const Color(0xFF3A2E12) : const Color(0xFFFFF4DB);
                final noteForeground =
                    isDark ? const Color(0xFFF3D38B) : const Color(0xFF7A5200);
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: noteBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: noteForeground),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.dailyPostPreviewStale,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: noteForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    preview.topicTitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _Pill(_dateLabel(context, preview.postDate, data.today)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(color: scheme.primary, width: 3),
                ),
              ),
              child: Text(
                preview.content,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: context.appTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: Text(preview == null
                    ? l10n.dailyPostPreviewGenerate
                    : l10n.dailyPostPreviewAgain),
                onPressed: saving || working
                    ? null
                    : () => bloc.add(
                        const FellowshipDailyPostActionRequested('preview')),
              ),
              if (data.settings.regenerateAllowed &&
                  preview != null &&
                  preview.isCurrent)
                OutlinedButton.icon(
                  icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: Text(data.settings.noLimits
                      ? l10n.dailyPostRegenerate
                      : l10n.dailyPostRegenerateLeft(regenerationsLeft)),
                  onPressed: saving ||
                          working ||
                          (!data.settings.noLimits && regenerationsLeft <= 0)
                      ? null
                      : () => bloc.add(const FellowshipDailyPostActionRequested(
                          'regenerate')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History
// ---------------------------------------------------------------------------

class _HistorySection extends StatelessWidget {
  final DailyPostStatusEntity data;
  final bool saving;

  const _HistorySection({required this.data, required this.saving});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    if (data.history.isEmpty) {
      return _Panel(
        child: Text(
          l10n.dailyPostHistoryEmpty,
          style: TextStyle(fontSize: 14, color: context.appTextSecondary),
        ),
      );
    }
    final meta = TextStyle(fontSize: 13, color: context.appTextSecondary);
    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < data.history.length; i++) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.history[i].topicTitle ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.event_outlined,
                            size: 14, color: context.appTextSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _dateLabel(
                              context, data.history[i].postDate, data.today),
                          style: meta,
                        ),
                      ]),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 14, color: context.appTextSecondary),
                        const SizedBox(width: 4),
                        Text(
                          l10n.dailyPostCompletedCount(
                              data.history[i].completedCount),
                          style: meta,
                        ),
                      ]),
                      if (data.history[i].postDeleted)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 14, color: context.appTextSecondary),
                          const SizedBox(width: 4),
                          Text(l10n.dailyPostPostDeleted, style: meta),
                        ]),
                    ],
                  ),
                  if (data.settings.postNowAllowed &&
                      data.history[i].dailyPostId != null)
                    _RepostButton(
                      data: data,
                      item: data.history[i],
                      saving: saving,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Post again" for one history item: replaces that post with a newly written
/// version of the same lesson. Works even when the post was already deleted.
class _RepostButton extends StatelessWidget {
  final DailyPostStatusEntity data;
  final DailyPostHistoryItemEntity item;
  final bool saving;

  const _RepostButton({
    required this.data,
    required this.item,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final reposting = data.isReposting(item.dailyPostId!);
    final anyRepostOpen = data.request('repost')?.isOpen ?? false;

    if (reposting) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: scheme.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.dailyPostWorking,
                style: TextStyle(fontSize: 13, color: context.appTextSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        icon: const Icon(Icons.refresh_rounded, size: 18),
        // The count explains a greyed-out button once today's limit is used.
        label: Text(data.settings.noLimits
            ? l10n.dailyPostRepost
            : l10n.dailyPostRepostLeft(data.repostsLeftToday)),
        onPressed: saving ||
                anyRepostOpen ||
                (!data.settings.noLimits && data.repostsLeftToday <= 0)
            ? null
            : () => _confirm(context),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<FellowshipDailyPostBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.dailyPostRepost),
        content: Text(item.postDeleted
            ? l10n.dailyPostRepostConfirmDeleted
            : l10n.dailyPostRepostConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.dailyPostCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.dailyPostRepost),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      bloc.add(FellowshipDailyPostActionRequested('repost',
          dailyPostId: item.dailyPostId));
    }
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: context.appTextPrimary),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context)!.dailyPostRetry),
            ),
          ],
        ),
      ),
    );
  }
}
