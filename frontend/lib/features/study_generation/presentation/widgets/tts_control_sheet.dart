import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../data/services/study_guide_tts_service.dart';

/// Bottom sheet for advanced TTS controls including speed and section navigation.
class TtsControlSheet extends StatefulWidget {
  const TtsControlSheet({super.key});

  @override
  State<TtsControlSheet> createState() => _TtsControlSheetState();
}

class _TtsControlSheetState extends State<TtsControlSheet> {
  late final StudyGuideTTSService _ttsService;

  // Available speed options
  static const List<double> _speedOptions = [0.75, 1.0, 1.25, 1.5];

  @override
  void initState() {
    super.initState();
    _ttsService = sl<StudyGuideTTSService>();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ValueListenableBuilder<StudyGuideTtsState>(
      valueListenable: _ttsService.state,
      builder: (context, state, child) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Text(
                    context.tr(TranslationKeys.studyGuideTtsControls),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Speed control section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(TranslationKeys.studyGuideTtsSpeed),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSpeedSelector(state.speechRate, isDark),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Playback controls (Previous, Play/Pause, Next)
                _buildPlaybackControls(state, isDark),

                const SizedBox(height: 24),

                // Section navigation
                if (_ttsService.hasGuide &&
                    _ttsService.sectionNames.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      context.tr(TranslationKeys.studyGuideTtsNowReading),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionList(state, theme, isDark),
                  const SizedBox(height: 24),
                ],

                // Stop button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _ttsService.stop();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.stop),
                      label:
                          Text(context.tr(TranslationKeys.studyGuideTtsStop)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: theme.colorScheme.error,
                        ),
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaybackControls(StudyGuideTtsState state, bool isDark) {
    final isPlaying = state.status == TtsStatus.playing;
    final isPaused = state.status == TtsStatus.paused;
    final canGoBack = state.currentSectionIndex > 0;
    final canGoForward =
        state.currentSectionIndex < _ttsService.totalSections - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous section button
          _buildControlButton(
            icon: Icons.skip_previous_rounded,
            onPressed:
                canGoBack ? () => _ttsService.skipToPreviousSection() : null,
            isDark: isDark,
            size: 48,
            iconSize: 28,
          ),
          const SizedBox(width: 24),
          // Play/Pause button (larger)
          _buildControlButton(
            icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            onPressed: (isPlaying || isPaused)
                ? () => _ttsService.togglePlayPause()
                : null,
            isDark: isDark,
            size: 64,
            iconSize: 36,
            isPrimary: true,
          ),
          const SizedBox(width: 24),
          // Next section button
          _buildControlButton(
            icon: Icons.skip_next_rounded,
            onPressed:
                canGoForward ? () => _ttsService.skipToNextSection() : null,
            isDark: isDark,
            size: 48,
            iconSize: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isDark,
    required double size,
    required double iconSize,
    bool isPrimary = false,
  }) {
    final isEnabled = onPressed != null;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPrimary
              ? (isEnabled
                  ? AppTheme.primaryColor
                  : AppTheme.primaryColor.withOpacity(0.5))
              : (isDark
                  ? (isEnabled ? Colors.grey.shade800 : Colors.grey.shade900)
                  : (isEnabled ? Colors.grey.shade200 : Colors.grey.shade100)),
          boxShadow: isPrimary && isEnabled
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: isPrimary
              ? Colors.white
              : (isEnabled
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.grey.shade700 : Colors.grey.shade400)),
        ),
      ),
    );
  }

  Widget _buildSpeedSelector(double currentSpeed, bool isDark) {
    return Row(
      children: _speedOptions.map((speed) {
        final isSelected = (currentSpeed - speed).abs() < 0.01;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => _ttsService.setSpeechRate(speed),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                        ),
                ),
                child: Center(
                  child: Text(
                    '${speed}x',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionList(
      StudyGuideTtsState state, ThemeData theme, bool isDark) {
    final sectionNames = _ttsService.sectionNames;
    final currentIndex = state.currentSectionIndex;
    final isPlaying = state.status == TtsStatus.playing;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: List.generate(sectionNames.length, (index) {
          final isCurrentSection = index == currentIndex;
          final sectionName =
              _getSectionDisplayName(context, sectionNames[index]);

          return InkWell(
            onTap: () => _ttsService.skipToSection(index),
            borderRadius: BorderRadius.vertical(
              top: index == 0 ? const Radius.circular(12) : Radius.zero,
              bottom: index == sectionNames.length - 1
                  ? const Radius.circular(12)
                  : Radius.zero,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isCurrentSection && isPlaying
                    ? AppTheme.primaryColor.withOpacity(0.1)
                    : null,
                border: index < sectionNames.length - 1
                    ? Border(
                        bottom: BorderSide(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  // Status indicator
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCurrentSection && isPlaying
                          ? AppTheme.primaryColor
                          : (isCurrentSection
                              ? AppTheme.primaryColor.withOpacity(0.3)
                              : Colors.transparent),
                      border: Border.all(
                        color: isCurrentSection
                            ? AppTheme.primaryColor
                            : (isDark
                                ? Colors.grey.shade600
                                : Colors.grey.shade400),
                        width: isCurrentSection ? 2 : 1,
                      ),
                    ),
                    child: isCurrentSection && isPlaying
                        ? const Icon(
                            Icons.play_arrow,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),

                  // Section name
                  Expanded(
                    child: Text(
                      sectionName,
                      style: TextStyle(
                        color: isCurrentSection
                            ? AppTheme.primaryColor
                            : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isCurrentSection
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 15,
                      ),
                    ),
                  ),

                  // Skip indicator
                  if (!isCurrentSection)
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color:
                          isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Get localized section display name.
  String _getSectionDisplayName(BuildContext context, String sectionTitle) {
    // Map section titles to translation keys
    switch (sectionTitle.toLowerCase()) {
      case 'summary':
        return context.tr(TranslationKeys.studyGuideSummary);
      case 'interpretation':
        return context.tr(TranslationKeys.studyGuideInterpretation);
      case 'context':
        return context.tr(TranslationKeys.studyGuideContext);
      case 'related verses':
        return context.tr(TranslationKeys.studyGuideRelatedVerses);
      case 'discussion questions':
        return context.tr(TranslationKeys.studyGuideDiscussionQuestions);
      case 'prayer points':
        return context.tr(TranslationKeys.studyGuidePrayerPoints);
      default:
        return sectionTitle;
    }
  }
}

/// Shows the TTS control sheet as a modal bottom sheet.
void showTtsControlSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const TtsControlSheet(),
  );
}
