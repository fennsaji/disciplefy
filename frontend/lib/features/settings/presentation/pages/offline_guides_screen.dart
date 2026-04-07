import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../study_generation/data/datasources/study_local_data_source.dart';
import '../../../study_generation/domain/entities/study_guide.dart';
import '../../../study_topics/data/models/learning_path_download_model.dart';
import '../../../study_topics/data/services/learning_path_download_service.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Offline Guides',
          style: AppFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1F2937),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _paths.isEmpty
              ? _buildEmptyState(isDark)
              : _buildPathList(isDark),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_outlined,
              size: 64,
              color: isDark
                  ? Colors.white.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No offline guides downloaded yet',
              style: AppFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withOpacity(0.6)
                    : const Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Download a learning path to access it offline',
              style: AppFonts.inter(
                fontSize: 14,
                color: isDark
                    ? Colors.white.withOpacity(0.4)
                    : const Color(0xFF9CA3AF),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPathList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: _paths.length,
      itemBuilder: (context, index) => _buildPathSection(_paths[index], isDark),
    );
  }

  Widget _buildPathSection(LearningPathDownloadModel path, bool isDark) {
    final completedTopics = path.topics
        .where((t) =>
            t.status == TopicDownloadStatus.done && t.cachedGuideId != null)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      path.learningPathTitle,
                      style: AppFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${path.completedCount} of ${path.totalCount} guides downloaded',
                      style: AppFonts.inter(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white.withOpacity(0.5)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey,
                  size: 20,
                ),
                tooltip: 'Delete all guides for this path',
                onPressed: () => _deletePath(path.learningPathId),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : AppTheme.primaryColor.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(isDark ? 0.1 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: completedTopics.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No completed guides in this path',
                    style: AppFonts.inter(
                      fontSize: 14,
                      color: isDark
                          ? Colors.white.withOpacity(0.4)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < completedTopics.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 20,
                          endIndent: 20,
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : AppTheme.primaryColor.withOpacity(0.08),
                        ),
                      _buildGuideTile(
                          completedTopics[i], path.learningPathId, isDark),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildGuideTile(
    LearningPathTopicDownload topic,
    String pathId,
    bool isDark,
  ) {
    final guide = _guidesById[topic.cachedGuideId];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: guide != null ? () => _openGuide(guide) : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.8),
                      AppTheme.primaryColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.book_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.topicTitle,
                      style: AppFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      topic.studyMode,
                      style: AppFonts.inter(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white.withOpacity(0.5)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: isDark ? Colors.white.withOpacity(0.4) : Colors.grey,
                  size: 20,
                ),
                tooltip: 'Delete this guide',
                onPressed: topic.cachedGuideId != null
                    ? () => _deleteGuide(pathId, topic.cachedGuideId!)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
