import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheet.dart';
import 'package:disciplefy_bible_study/features/study_generation/data/datasources/study_local_data_source.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_guide.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/models/learning_path_download_model.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_path_download_service.dart';

class OfflineGuidesScreen extends StatefulWidget {
  const OfflineGuidesScreen({super.key});

  @override
  State<OfflineGuidesScreen> createState() => _OfflineGuidesScreenState();
}

class _OfflineGuidesScreenState extends State<OfflineGuidesScreen> {
  List<LearningPathDownloadModel> _paths = [];
  Map<String, StudyGuide> _guidesById = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final paths = await sl<LearningPathDownloadService>().getAllDownloads();
    final completed =
        paths.where((p) => p.status == PathDownloadStatus.completed).toList();

    final allGuides = await sl<StudyLocalDataSource>().getCachedStudyGuides();
    final guidesById = {for (final g in allGuides) g.id: g};

    if (mounted) {
      setState(() {
        _paths = completed;
        _guidesById = guidesById;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteGuide(String pathId, String guideId) async {
    await sl<LearningPathDownloadService>().deleteTopic(pathId, guideId);
    await _loadData();
  }

  Future<void> _deletePath(String pathId) async {
    await sl<LearningPathDownloadService>().deleteDownload(pathId);
    await _loadData();
  }

  /// Removes every downloaded path (the per-path delete, for each), after
  /// confirming.
  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SettingsDialog(
        title: dialogContext.tr(TranslationKeys.settingsOfflineClearAllTitle),
        content: Text(
            dialogContext.tr(TranslationKeys.settingsOfflineClearAllMessage)),
        actions: [
          SettingsButton(
            label: dialogContext.tr(TranslationKeys.commonCancel),
            kind: SettingsButtonKind.neutral,
            height: 46,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          SettingsButton(
            label: dialogContext.tr(TranslationKeys.settingsOfflineClearAll),
            kind: SettingsButtonKind.destructive,
            height: 46,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final service = sl<LearningPathDownloadService>();
    for (final path in List.of(_paths)) {
      await service.deleteDownload(path.learningPathId);
    }
    await _loadData();
  }

  List<LearningPathTopicDownload> _completedTopics(
          LearningPathDownloadModel path) =>
      path.topics
          .where((t) =>
              t.status == TopicDownloadStatus.done && t.cachedGuideId != null)
          .toList();

  void _openGuide(StudyGuide guide) {
    context.go('/study-guide', extra: {
      'study_guide': {
        'id': guide.id,
        'type': guide.inputType,
        'title': guide.input,
        'summary': guide.summary,
        'interpretation': guide.interpretation,
        'context': guide.context,
        'related_verses': guide.relatedVerses,
        'reflection_questions': guide.reflectionQuestions,
        'prayer_points': guide.prayerPoints,
        'is_saved': guide.isSaved ?? false,
        'personal_notes': guide.personalNotes,
        'passage': guide.passage,
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);

    return Scaffold(
      backgroundColor: palette.page,
      appBar: SettingsTopBar(
        title: context.tr(TranslationKeys.settingsOfflineGuides),
        subtitle: context.tr(TranslationKeys.settingsOfflineGuidesSubtitle),
        onBack: () => context.pop(),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: settingsPrimaryFill))
          : _paths.isEmpty
              ? _buildEmptyState()
              : _buildPathList(),
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
              icon: Icons.wifi_off_outlined,
              tone: SettingsTone.green,
              size: 64,
            ),
            const SizedBox(height: 18),
            Text(
              context.tr(TranslationKeys.settingsOfflineEmptyTitle),
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(TranslationKeys.settingsOfflineEmptySubtitle),
              textAlign: TextAlign.center,
              style: AppFonts.inter(fontSize: 14, color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPathList() {
    final guideCount =
        _paths.fold<int>(0, (sum, p) => sum + _completedTopics(p).length);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        _StorageCard(
          label: context.tr(TranslationKeys.settingsOfflineGuidesCount,
              {'count': '$guideCount'}),
          clearLabel: context.tr(TranslationKeys.settingsOfflineClearAll),
          onClearAll: _confirmClearAll,
        ),
        for (final path in _paths) ..._buildPathSection(path),
      ],
    );
  }

  List<Widget> _buildPathSection(LearningPathDownloadModel path) {
    final palette = ReaderPalette.of(context);
    final completedTopics = _completedTopics(path);
    final removeLabel = context.tr(TranslationKeys.settingsOfflineRemove);

    return [
      SettingsSectionLabel(
        path.learningPathTitle,
        trailing: Semantics(
          button: true,
          label: '$removeLabel ${path.learningPathTitle}',
          excludeSemantics: true,
          child: IconButton(
            tooltip: '$removeLabel ${path.learningPathTitle}',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline, size: 18, color: palette.dim),
            onPressed: () => _deletePath(path.learningPathId),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
        child: Text(
          context.tr(TranslationKeys.settingsOfflinePathProgress, {
            'done': '${path.completedCount}',
            'total': '${path.totalCount}',
          }),
          style: AppFonts.inter(fontSize: 12, color: palette.muted),
        ),
      ),
      SettingsGroup(
        children: completedTopics.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.tr(TranslationKeys.settingsOfflinePathEmpty),
                    style: AppFonts.inter(fontSize: 14, color: palette.muted),
                  ),
                ),
              ]
            : [
                for (final topic in completedTopics)
                  _buildGuideTile(topic, path.learningPathId, removeLabel),
              ],
      ),
    ];
  }

  Widget _buildGuideTile(
    LearningPathTopicDownload topic,
    String pathId,
    String removeLabel,
  ) {
    final guide = _guidesById[topic.cachedGuideId];
    final palette = ReaderPalette.of(context);

    return SettingsRow(
      icon: Icons.file_download_done_outlined,
      tone: SettingsTone.green,
      title: topic.topicTitle,
      subtitle: topic.studyMode,
      showChevron: false,
      onTap: guide != null ? () => _openGuide(guide) : null,
      trailing: TextButton(
        onPressed: topic.cachedGuideId != null
            ? () => _deleteGuide(pathId, topic.cachedGuideId!)
            : null,
        style: TextButton.styleFrom(
          foregroundColor: palette.muted,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(48, 40),
        ),
        child: Text(
          removeLabel,
          style: AppFonts.inter(fontSize: 13.5, color: palette.muted),
        ),
      ),
    );
  }
}

/// "N guides" with a red "Clear all" action.
class _StorageCard extends StatelessWidget {
  final String label;
  final String clearLabel;
  final VoidCallback onClearAll;

  const _StorageCard({
    required this.label,
    required this.clearLabel,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final red = SettingsToneColors.of(context, SettingsTone.red);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
          ),
          TextButton(
            onPressed: onClearAll,
            style: TextButton.styleFrom(foregroundColor: red.foreground),
            child: Text(
              clearLabel,
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: red.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
