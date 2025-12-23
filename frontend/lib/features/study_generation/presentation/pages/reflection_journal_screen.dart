import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/datasources/reflections_remote_data_source.dart';
import '../../data/repositories/reflections_repository_impl.dart';
import '../../domain/entities/reflection_response.dart';
import '../../domain/entities/study_mode.dart';
import '../../domain/repositories/reflections_repository.dart';

/// Screen displaying the user's reflection journal.
///
/// Shows a paginated list of past reflections grouped by date,
/// with the ability to expand and view full reflection details.
class ReflectionJournalScreen extends StatefulWidget {
  const ReflectionJournalScreen({super.key});

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
    final supabase = Supabase.instance.client;
    final remoteDataSource = ReflectionsRemoteDataSourceImpl(
      supabaseClient: supabase,
    );
    _repository = ReflectionsRepositoryImpl(
      remoteDataSource: remoteDataSource,
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

      setState(() {
        _reflections = listResult.reflections;
        _stats = stats;
        _hasMore = listResult.hasMore;
        _currentPage = 1;
        _isLoading = false;
      });
    } catch (e) {
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

  Future<void> _deleteReflection(String reflectionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reflection'),
        content: const Text('Are you sure you want to delete this reflection?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reflection deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Reflection Journal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          PopupMenuButton<StudyMode?>(
            icon: Icon(
              Icons.filter_list,
              color: _selectedMode != null ? AppTheme.primaryColor : null,
            ),
            tooltip: 'Filter by mode',
            onSelected: _onModeFilterChanged,
            itemBuilder: (context) => [
              const PopupMenuItem(
                child: Text('All Modes'),
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
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitialData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_reflections.isEmpty) {
      return _buildEmptyState(theme);
    }

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Stats header
          if (_stats != null) _buildStatsHeader(theme),

          // Filter chip (if active)
          if (_selectedMode != null)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Wrap(
                  children: [
                    Chip(
                      label: Text(
                          '${_selectedMode!.icon} ${_selectedMode!.displayName}'),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () => _onModeFilterChanged(null),
                    ),
                  ],
                ),
              ),
            ),

          // Reflections list grouped by date
          ..._buildGroupedReflections(theme),

          // Loading more indicator
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No reflections yet',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Complete a study guide in Reflect Mode to see your reflections here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/study'),
              icon: const Icon(Icons.add),
              label: const Text('Start a Study'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader(ThemeData theme) {
    final stats = _stats!;

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withOpacity(0.1),
              AppTheme.secondaryColor.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Journey',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatItem(
                  theme,
                  icon: Icons.auto_stories,
                  value: stats.totalReflections.toString(),
                  label: 'Reflections',
                ),
                const SizedBox(width: 24),
                _buildStatItem(
                  theme,
                  icon: Icons.timer_outlined,
                  value: stats.formattedTotalTime,
                  label: 'Time Spent',
                ),
                const SizedBox(width: 24),
                _buildStatItem(
                  theme,
                  icon: Icons.speed,
                  value: '${stats.averageTimeMinutes}m',
                  label: 'Avg/Session',
                ),
              ],
            ),
            if (stats.mostCommonLifeAreas.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Top focus areas:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: stats.mostCommonLifeAreas.map((area) {
                  final lifeArea = LifeAreas.all.firstWhere(
                    (la) => la.id == area,
                    orElse: () =>
                        LifeAreaOption(id: area, label: area, icon: '•'),
                  );
                  return Chip(
                    label: Text('${lifeArea.icon} ${lifeArea.label}'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    ThemeData theme, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedReflections(ThemeData theme) {
    // Group reflections by date
    final grouped = <String, List<ReflectionSession>>{};
    final dateFormat = DateFormat('MMMM d, yyyy');

    for (final reflection in _reflections) {
      final date = reflection.completedAt ?? reflection.createdAt;
      final dateKey = dateFormat.format(date);
      grouped.putIfAbsent(dateKey, () => []).add(reflection);
    }

    final widgets = <Widget>[];

    for (final entry in grouped.entries) {
      // Date header
      widgets.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            entry.key,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.textTheme.bodySmall?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ));

      // Reflections for this date
      widgets.add(SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildReflectionCard(theme, entry.value[index]),
          childCount: entry.value.length,
        ),
      ));
    }

    return widgets;
  }

  Widget _buildReflectionCard(ThemeData theme, ReflectionSession reflection) {
    final isExpanded = _expandedReflectionId == reflection.id;
    final timeFormat = DateFormat('h:mm a');
    final time =
        timeFormat.format(reflection.completedAt ?? reflection.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _toggleExpanded(reflection.id),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${reflection.studyMode.icon} ${reflection.studyMode.displayName}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(reflection.timeSpentSeconds / 60).round()}m',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more, size: 20),
                  ),
                ],
              ),

              // Summary of responses (always visible)
              if (reflection.responses.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildResponseSummary(theme, reflection),
              ],

              // Expanded details
              if (isExpanded) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                _buildExpandedDetails(theme, reflection),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        // Navigate to study guide
                        context.push('/study-guide/${reflection.studyGuideId}');
                      },
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View Study'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: reflection.id != null
                          ? () => _deleteReflection(reflection.id!)
                          : null,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
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

  Widget _buildResponseSummary(ThemeData theme, ReflectionSession reflection) {
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
            summaryItems.add('${verses.length} verses saved');
          }
          break;
        default:
          break;
      }
    }

    if (summaryItems.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: summaryItems.take(3).map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            item,
            style: theme.textTheme.bodySmall,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExpandedDetails(ThemeData theme, ReflectionSession reflection) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: reflection.responses.map((response) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildResponseDetail(theme, response),
        );
      }).toList(),
    );
  }

  Widget _buildResponseDetail(ThemeData theme, ReflectionResponse response) {
    final valueWidget = _buildResponseValue(theme, response);
    if (valueWidget == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          response.sectionTitle,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        valueWidget,
      ],
    );
  }

  Widget? _buildResponseValue(ThemeData theme, ReflectionResponse response) {
    switch (response.interactionType) {
      case ReflectionInteractionType.tapSelection:
        if (response.value == null) return null;
        return Text(response.value as String,
            style: theme.textTheme.bodyMedium);

      case ReflectionInteractionType.slider:
        if (response.value == null) return null;
        final value = (response.value as double) * 100;
        return Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: response.value as double,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(width: 8),
            Text('${value.round()}%', style: theme.textTheme.bodySmall),
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
                  color: isYes ? Colors.green : Colors.red[300],
                ),
                const SizedBox(width: 4),
                Text(isYes ? 'Yes' : 'No', style: theme.textTheme.bodyMedium),
              ],
            ),
            if (response.additionalText != null &&
                response.additionalText!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                response.additionalText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
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
          runSpacing: 4,
          children: items.map((item) {
            return Chip(
              label: Text(item),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
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
            Text(mode.displayName, style: theme.textTheme.bodyMedium),
            const SizedBox(width: 16),
            Icon(Icons.timer_outlined,
                size: 16, color: theme.textTheme.bodySmall?.color),
            const SizedBox(width: 4),
            Text('${(duration / 60).round()}m',
                style: theme.textTheme.bodySmall),
          ],
        );
    }
  }
}
