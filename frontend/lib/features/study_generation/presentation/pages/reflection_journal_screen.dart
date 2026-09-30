import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheet.dart';
import 'package:disciplefy_bible_study/features/study_generation/data/datasources/reflections_remote_data_source.dart';
import 'package:disciplefy_bible_study/features/study_generation/data/repositories/reflections_repository_impl.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/reflection_response.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/repositories/reflections_repository.dart';
import '../../../../shared/widgets/app_snackbar.dart';

/// Screen displaying the user's reflection journal.
///
/// Shows a paginated list of past reflections grouped by date,
/// with the ability to expand and view full reflection details.
class ReflectionJournalScreen extends StatefulWidget {
  /// Overrides the Supabase-backed repository (tests).
  @visibleForTesting
  final ReflectionsRepository? repository;

  const ReflectionJournalScreen({super.key, this.repository});

  @override
  State<ReflectionJournalScreen> createState() =>
      _ReflectionJournalScreenState();
}

class _ReflectionJournalScreenState extends State<ReflectionJournalScreen> {
  late final ReflectionsRepository _repository;
  final ScrollController _scrollController = ScrollController();

  List<ReflectionSession> _reflections = [];
  ReflectionStats? _stats;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _error;
  StudyMode? _selectedMode;
  String? _expandedReflectionId;

  @override
  void initState() {
    super.initState();
    _initRepository();
    _scrollController.addListener(_onScroll);
  }

  void _initRepository() {
    final injected = widget.repository;
    if (injected != null) {
      _repository = injected;
      _loadInitialData();
      return;
    }
    final supabase = Supabase.instance.client;
    final remoteDataSource = ReflectionsRemoteDataSourceImpl(
      supabaseClient: supabase,
    );
    _repository = ReflectionsRepositoryImpl(
      remoteDataSource: remoteDataSource,
      networkInfo: sl(),
    );
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _repository.listReflections(studyMode: _selectedMode),
        _repository.getReflectionStats(),
      ]);

      final listResult = results[0] as ReflectionListResult;
      final stats = results[1] as ReflectionStats;

      if (!mounted) return;
      setState(() {
        _reflections = listResult.reflections;
        _stats = stats;
        _hasMore = listResult.hasMore;
        _currentPage = 1;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load reflections: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreReflections() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final result = await _repository.listReflections(
        page: _currentPage + 1,
        studyMode: _selectedMode,
      );

      setState(() {
        _reflections.addAll(result.reflections);
        _hasMore = result.hasMore;
        _currentPage++;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreReflections();
    }
  }

  void _onModeFilterChanged(StudyMode? mode) {
    setState(() {
      _selectedMode = mode;
      _reflections = [];
      _currentPage = 1;
      _hasMore = true;
    });
    _loadInitialData();
  }

  void _toggleExpanded(String? reflectionId) {
    setState(() {
      _expandedReflectionId =
          _expandedReflectionId == reflectionId ? null : reflectionId;
    });
  }

  Future<void> _viewStudyGuide(
      BuildContext context, ReflectionSession reflection) async {
    try {
      // Fetch study guide data from database
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('study_guides')
          .select()
          .eq('id', reflection.studyGuideId)
          .single();

      // Navigate with full study guide data
      if (mounted) {
        context.push('/study-guide?source=reflection_journal', extra: {
          'study_guide': {
            'id': response['id'],
            'title': response['input_value'] ?? '',
            'content': '',
            'type': response['input_type'] ?? 'scripture',
            'verse_reference': response['input_value'],
            'topic_name': response['input_value'],
            'is_saved': true,
            'created_at': response['created_at'],
            'last_accessed_at': response['updated_at'],
            'summary': response['summary'],
            'interpretation': response['interpretation'],
            'context': response['context'],
            'related_verses': response['related_verses'],
            'reflection_questions': response['reflection_questions'],
            'prayer_points': response['prayer_points'],
            'interpretation_insights': response['interpretation_insights'],
            'summary_insights': response['summary_insights'],
            'reflection_answers': response['reflection_answers'],
            'context_question': response['context_question'],
            'summary_question': response['summary_question'],
            'related_verses_question': response['related_verses_question'],
            'reflection_question': response['reflection_question'],
            'prayer_question': response['prayer_question'],
          }
        });
      }
    } catch (e, stackTrace) {
      // Log error with stack trace (metadata only, no user content)
      Logger.debug('[ReflectionJournal] Failed to load study guide: $e');
      Logger.debug('[ReflectionJournal] Stack trace: $stackTrace');

      // Show user-friendly error message without raw exception
      if (mounted) {
        showAppSnackBar(
          context,
          context.tr(TranslationKeys.reflectionJournalLoadStudyFailed),
          tone: AppSnackTone.error,
        );
      }
    }
  }

  Future<void> _deleteReflection(String reflectionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SettingsDialog(
        title: context.tr(TranslationKeys.reflectionJournalDeleteTitle),
        content:
            Text(context.tr(TranslationKeys.reflectionJournalDeleteMessage)),
        actions: [
          SettingsButton(
            label: context.tr(TranslationKeys.reflectionJournalCancel),
            kind: SettingsButtonKind.neutral,
            height: 46,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          SettingsButton(
            label: context.tr(TranslationKeys.reflectionJournalDelete),
            kind: SettingsButtonKind.destructive,
            height: 46,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.deleteReflection(reflectionId);
        setState(() {
          _reflections.removeWhere((r) => r.id == reflectionId);
        });
        if (mounted) {
          showAppSnackBar(
            context,
            context.tr(TranslationKeys.reflectionJournalDeleted),
            tone: AppSnackTone.success,
          );
        }
      } catch (e) {
        Logger.error('Failed to delete reflection', error: e);
        if (mounted) {
          showAppSnackBar(
            context,
            context.tr(TranslationKeys.reflectionJournalDeleteFailed),
            tone: AppSnackTone.error,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final stats = _stats;

    return Scaffold(
      backgroundColor: palette.page,
      appBar: SettingsTopBar(
        title: context.tr(TranslationKeys.reflectionJournalTitle),
        subtitle: stats == null
            ? null
            : context.tr(TranslationKeys.reflectionJournalCount,
                {'count': '${stats.totalReflections}'}),
        onBack: () => context.pop(),
        actions: [
          PopupMenuButton<StudyMode?>(
            icon: Icon(
              Icons.filter_list,
              color: _selectedMode != null ? palette.accentIcon : palette.muted,
            ),
            tooltip: context.tr(TranslationKeys.reflectionJournalFilterByMode),
            color: palette.card,
            onSelected: _onModeFilterChanged,
            itemBuilder: (context) => [
              PopupMenuItem(
                child:
                    Text(context.tr(TranslationKeys.reflectionJournalAllModes)),
              ),
              ...StudyMode.values.map((mode) => PopupMenuItem(
                    value: mode,
                    child: Row(
                      children: [
                        Text(mode.icon),
                        const SizedBox(width: 8),
                        Text(mode.displayName),
                        if (_selectedMode == mode) ...[
                          const Spacer(),
                          const Icon(Icons.check, size: 18),
                        ],
                      ],
                    ),
                  )),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final palette = ReaderPalette.of(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: settingsPrimaryFill),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SettingsIconTile(
                icon: Icons.error_outline,
                tone: SettingsTone.red,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppFonts.inter(fontSize: 14, color: palette.muted),
              ),
              const SizedBox(height: 20),
              SettingsButton(
                label: context.tr(TranslationKeys.reflectionJournalRetry),
                height: 46,
                onPressed: _loadInitialData,
              ),
            ],
          ),
        ),
      );
    }

    if (_reflections.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          if (_stats != null) _buildStatsHeader(),

          // Active filter
          if (_selectedMode != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _ActiveFilterPill(
                    label:
                        '${_selectedMode!.icon} ${_selectedMode!.displayName}',
                    onClear: () => _onModeFilterChanged(null),
                  ),
                ),
              ),
            ),

          // Reflections grouped under a heading per day.
          ..._buildGroupedReflections(),

          // Loading more indicator
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(color: settingsPrimaryFill),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final palette = ReaderPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SettingsIconTile(
              icon: Icons.auto_stories_outlined,
              tone: SettingsTone.pink,
              size: 64,
            ),
            const SizedBox(height: 18),
            Text(
              context.tr(TranslationKeys.reflectionJournalNoReflections),
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(TranslationKeys.reflectionJournalEmptyMessage),
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 14,
                color: palette.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            SettingsButton(
              label: context.tr(TranslationKeys.reflectionJournalStartStudy),
              icon: Icons.add,
              height: 46,
              onPressed: () => context.go(AppRoutes.generateStudy),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    final stats = _stats!;
    final palette = ReaderPalette.of(context);
    final focusTitle = context
        .tr(TranslationKeys.reflectionJournalTopFocusAreas)
        .replaceAll(RegExp(r'[:：]\s*$'), '');

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsSectionLabel(
                context.tr(TranslationKeys.reflectionJournalYourJourney)),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SettingsStatTile(
                      icon: Icons.auto_stories_outlined,
                      tone: SettingsTone.pink,
                      value: stats.totalReflections.toString(),
                      label: context
                          .tr(TranslationKeys.reflectionJournalReflections),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SettingsStatTile(
                      icon: Icons.timer_outlined,
                      tone: SettingsTone.sky,
                      value: stats.formattedTotalTime,
                      label: context
                          .tr(TranslationKeys.reflectionJournalTimeSpent),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SettingsStatTile(
                      icon: Icons.speed,
                      value: '${stats.averageTimeMinutes}m',
                      label: context
                          .tr(TranslationKeys.reflectionJournalAvgSession),
                    ),
                  ),
                ],
              ),
            ),
            if (stats.mostCommonLifeAreas.isNotEmpty) ...[
              SettingsSectionLabel(focusTitle),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: stats.mostCommonLifeAreas.map((area) {
                  final lifeArea = LifeAreas.all.firstWhere(
                    (la) => la.id == area,
                    orElse: () =>
                        LifeAreaOption(id: area, label: area, icon: '•'),
                  );
                  return _SoftChip(
                    label: lifeArea.icon != null
                        ? '${lifeArea.icon} ${lifeArea.label}'
                        : lifeArea.label,
                    palette: palette,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Day heading: "Today", "Yesterday" or the full date.
  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return context.tr(TranslationKeys.reflectionJournalToday);
    if (diff == 1) {
      return context.tr(TranslationKeys.reflectionJournalYesterday);
    }
    return DateFormat('MMMM d, yyyy').format(date);
  }

  /// A date heading followed by that day's cards, newest day first (the
  /// order the list arrives in).
  List<Widget> _buildGroupedReflections() {
    final groups = <DateTime, List<ReflectionSession>>{};
    for (final reflection in _reflections) {
      final date = reflection.completedAt ?? reflection.createdAt;
      groups
          .putIfAbsent(DateTime(date.year, date.month, date.day), () => [])
          .add(reflection);
    }
    return [
      for (final entry in groups.entries)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _DateHeading(_dayLabel(entry.key)),
              for (final reflection in entry.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildReflectionCard(reflection),
                ),
            ]),
          ),
        ),
    ];
  }

  /// First written or tapped answer, shown as the card's quoted excerpt.
  String? _excerpt(ReflectionSession reflection) {
    for (final response in reflection.responses) {
      final text = response.additionalText;
      if (text != null && text.trim().isNotEmpty) return text.trim();
    }
    for (final response in reflection.responses) {
      if (response.interactionType == ReflectionInteractionType.tapSelection &&
          response.value is String &&
          (response.value as String).trim().isNotEmpty) {
        return (response.value as String).trim();
      }
    }
    return null;
  }

  Widget _buildReflectionCard(ReflectionSession reflection) {
    final palette = ReaderPalette.of(context);
    final isExpanded = _expandedReflectionId == reflection.id;
    final date = reflection.completedAt ?? reflection.createdAt;
    final time = DateFormat('h:mm a').format(date);
    final minutes = (reflection.timeSpentSeconds / 60).round();
    final excerpt = _excerpt(reflection);
    final chips = _summaryItems(reflection)
        .where((item) => item != excerpt)
        .take(3)
        .toList();

    return Material(
      color: palette.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: palette.hairline),
      ),
      child: InkWell(
        onTap: () => _toggleExpanded(reflection.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${reflection.studyMode.icon} ${reflection.studyMode.displayName}',
                      style: AppFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr(TranslationKeys.reflectionJournalMinutes,
                        {'minutes': '$minutes'}),
                    style: AppFonts.inter(fontSize: 12, color: palette.dim),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: palette.dim,
                  ),
                ],
              ),
              if (excerpt != null) ...[
                const SizedBox(height: 8),
                Text(
                  '“$excerpt”',
                  maxLines: isExpanded ? null : 3,
                  overflow: isExpanded ? null : TextOverflow.ellipsis,
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: palette.text.withValues(alpha: 0.85),
                    height: 1.45,
                  ),
                ),
              ],
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final item in chips)
                      _SoftChip(label: item, palette: palette),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                time,
                style: AppFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: palette.gold,
                ),
              ),

              // Expanded details
              if (isExpanded) ...[
                const SizedBox(height: 12),
                Container(height: 1, color: palette.hairline),
                const SizedBox(height: 12),
                _buildExpandedDetails(reflection),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () => _viewStudyGuide(context, reflection),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: Text(context
                          .tr(TranslationKeys.reflectionJournalViewStudy)),
                      style: TextButton.styleFrom(
                          foregroundColor: palette.accentIcon),
                    ),
                    TextButton.icon(
                      onPressed: reflection.id != null
                          ? () => _deleteReflection(reflection.id!)
                          : null,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(
                          context.tr(TranslationKeys.reflectionJournalDelete)),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            SettingsToneColors.of(context, SettingsTone.red)
                                .foreground,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<String> _summaryItems(ReflectionSession reflection) {
    final summaryItems = <String>[];

    for (final response in reflection.responses) {
      switch (response.interactionType) {
        case ReflectionInteractionType.tapSelection:
          if (response.value != null) {
            summaryItems.add(response.value as String);
          }
          break;
        case ReflectionInteractionType.multiSelect:
          final areas = response.value as List<String>?;
          if (areas != null && areas.isNotEmpty) {
            summaryItems.addAll(areas.take(2));
          }
          break;
        case ReflectionInteractionType.verseSelection:
          final verses = response.value as List<String>?;
          if (verses != null && verses.isNotEmpty) {
            summaryItems.add(context
                .tr(TranslationKeys.reflectionJournalVersesSaved)
                .replaceAll('{count}', verses.length.toString()));
          }
          break;
        default:
          break;
      }
    }
    return summaryItems;
  }

  Widget _buildExpandedDetails(ReflectionSession reflection) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: reflection.responses.map((response) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildResponseDetail(response),
        );
      }).toList(),
    );
  }

  Widget _buildResponseDetail(ReflectionResponse response) {
    final palette = ReaderPalette.of(context);
    final valueWidget = _buildResponseValue(response);
    if (valueWidget == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          response.sectionTitle.toUpperCase(),
          style: AppFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 4),
        valueWidget,
      ],
    );
  }

  Widget? _buildResponseValue(ReflectionResponse response) {
    final palette = ReaderPalette.of(context);
    final body = AppFonts.inter(fontSize: 14, color: palette.text, height: 1.4);
    final small = AppFonts.inter(fontSize: 12.5, color: palette.muted);

    switch (response.interactionType) {
      case ReflectionInteractionType.tapSelection:
        if (response.value == null) return null;
        return Text(response.value as String, style: body);

      case ReflectionInteractionType.slider:
        if (response.value == null) return null;
        final value = (response.value as double) * 100;
        return Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: response.value as double,
                  minHeight: 6,
                  backgroundColor: palette.raised,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(settingsPrimaryFill),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('${value.round()}%', style: small),
          ],
        );

      case ReflectionInteractionType.yesNo:
        if (response.value == null) return null;
        final isYes = response.value as bool;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isYes ? Icons.check_circle : Icons.cancel,
                  size: 18,
                  color: isYes ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 4),
                Text(
                  isYes
                      ? context.tr(TranslationKeys.reflectionJournalYes)
                      : context.tr(TranslationKeys.reflectionJournalNo),
                  style: body,
                ),
              ],
            ),
            if (response.additionalText != null &&
                response.additionalText!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                response.additionalText!,
                style: small.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        );

      case ReflectionInteractionType.multiSelect:
      case ReflectionInteractionType.verseSelection:
        final items = response.value as List<String>?;
        if (items == null || items.isEmpty) return null;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final item in items) _SoftChip(label: item, palette: palette),
          ],
        );

      case ReflectionInteractionType.prayer:
        final prayerData = response.value as Map<String, dynamic>?;
        if (prayerData == null) return null;
        final mode =
            PrayerModeExtension.fromString(prayerData['mode'] as String?);
        final duration = prayerData['duration'] as int? ?? 0;
        return Row(
          children: [
            Text(mode.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Flexible(child: Text(mode.displayName, style: body)),
            const SizedBox(width: 16),
            Icon(Icons.timer_outlined, size: 16, color: palette.muted),
            const SizedBox(width: 4),
            Text('${(duration / 60).round()}m', style: small),
          ],
        );
    }
  }
}

/// Small raised pill for answers and focus areas.
class _SoftChip extends StatelessWidget {
  final String label;
  final ReaderPalette palette;

  const _SoftChip({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: palette.raised,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: AppFonts.inter(fontSize: 12.5, color: palette.text),
        ),
      );
}

/// The active mode filter, with a clear button.
class _ActiveFilterPill extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const _ActiveFilterPill({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final indigo = SettingsToneColors.of(context, SettingsTone.indigo);
    return Material(
      color: indigo.fill,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onClear,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: AppFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.accentIcon,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.close, size: 16, color: palette.accentIcon),
            ],
          ),
        ),
      ),
    );
  }
}

/// Day heading above a group of reflection cards.
class _DateHeading extends StatelessWidget {
  final String text;

  const _DateHeading(this.text);

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: AppFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: palette.muted,
          ),
        ),
      ),
    );
  }
}
