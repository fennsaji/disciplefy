import 'package:flutter/material.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/theme/reader_palette.dart';
import '../../data/services/study_guide_tts_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart'
    show SettingsButton, SettingsButtonKind;
import 'package:disciplefy_bible_study/shared/widgets/popup.dart'
    show PopupEyebrow, kPopupRadius;
import 'package:disciplefy_bible_study/shared/widgets/sheet_scroll_view.dart';

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

  // Scrubber state — true while the user is dragging the seek slider
  bool _isScrubbing = false;
  double _scrubValue = 0.0;

  @override
  void initState() {
    super.initState();
    _ttsService = sl<StudyGuideTTSService>();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);

    return ValueListenableBuilder<StudyGuideTtsState>(
      valueListenable: _ttsService.state,
      builder: (context, state, child) {
        return Container(
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(kPopupRadius)),
            border: Border(top: BorderSide(color: palette.hairline)),
          ),
          child: SafeArea(
            child: SheetScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Eyebrow and title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PopupEyebrow(
                          context.tr(TranslationKeys.studyGuideListen),
                          textAlign: TextAlign.start,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr(TranslationKeys.studyGuideTtsControls),
                          style: AppFonts.poppins(
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                            color: palette.text,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Speed control section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel(
                            context.tr(TranslationKeys.studyGuideTtsSpeed)),
                        const SizedBox(height: 12),
                        _buildSpeedSelector(state.speechRate, palette),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Progress bar for section navigation
                  if (_ttsService.hasGuide && _ttsService.totalSections > 1)
                    _buildProgressBar(state, palette),

                  const SizedBox(height: 20),

                  // Playback controls (Previous, Play/Pause, Next)
                  _buildPlaybackControls(state, palette),

                  const SizedBox(height: 24),

                  // Section navigation
                  if (_ttsService.hasGuide &&
                      _ttsService.sectionNames.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _sectionLabel(
                          context.tr(TranslationKeys.studyGuideTtsNowReading)),
                    ),
                    const SizedBox(height: 12),
                    _buildSectionList(state, palette),
                    const SizedBox(height: 24),
                  ],

                  // Stop button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: SettingsButton(
                        key: const Key('tts_stop_button'),
                        label: context.tr(TranslationKeys.studyGuideTtsStop),
                        icon: Icons.stop_rounded,
                        kind: SettingsButtonKind.destructive,
                        onPressed: () {
                          _ttsService.stop();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Gold tracked label above a group of controls.
  Widget _sectionLabel(String text) =>
      PopupEyebrow(text, textAlign: TextAlign.start);

  Widget _buildPlaybackControls(
      StudyGuideTtsState state, ReaderPalette palette) {
    final isPlaying = state.status == TtsStatus.playing;
    final isPaused = state.status == TtsStatus.paused;
    final isCompleted = state.status == TtsStatus.completed;
    final isLoading = state.status == TtsStatus.loading;
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
            palette: palette,
            size: 48,
            iconSize: 28,
            semanticLabel:
                context.tr(TranslationKeys.guideFeedbackTtsPrevSection),
          ),
          const SizedBox(width: 24),
          // Play/Pause/Loading button (larger)
          if (isLoading)
            _buildLoadingButton(palette)
          else
            _buildControlButton(
              icon: isPlaying
                  ? Icons.pause_rounded
                  : (isCompleted
                      ? Icons.replay_rounded
                      : Icons.play_arrow_rounded),
              onPressed: (isPlaying || isPaused || isCompleted)
                  ? () => _ttsService.togglePlayPause()
                  : null,
              palette: palette,
              size: 64,
              iconSize: 36,
              semanticLabel: context.tr(isPlaying
                  ? TranslationKeys.studyGuidePause
                  : (isCompleted
                      ? TranslationKeys.guideFeedbackTtsReplay
                      : TranslationKeys.guideFeedbackTtsPlay)),
              isPrimary: true,
            ),
          const SizedBox(width: 24),
          // Next section button
          _buildControlButton(
            icon: Icons.skip_next_rounded,
            onPressed:
                canGoForward ? () => _ttsService.skipToNextSection() : null,
            palette: palette,
            size: 48,
            iconSize: 28,
            semanticLabel:
                context.tr(TranslationKeys.guideFeedbackTtsNextSection),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingButton(ReaderPalette palette) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.ctaFill,
      ),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: palette.ctaInk,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(StudyGuideTtsState state, ReaderPalette palette) {
    final totalSections = _ttsService.totalSections;
    final currentIndex = state.currentSectionIndex;
    final sectionNames = _ttsService.sectionNames;
    final sectionProgress = state.sectionProgress;
    final elapsedSeconds = state.elapsedSeconds;
    final estimatedSeconds = state.estimatedDurationSeconds;

    // Format time as M:SS
    String formatTime(int seconds) {
      final mins = seconds ~/ 60;
      final secs = seconds % 60;
      return '$mins:${secs.toString().padLeft(2, '0')}';
    }

    final timeStyle = AppFonts.inter(fontSize: 12, color: palette.muted);
    final shownProgress = _isScrubbing ? _scrubValue : sectionProgress;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current section label and section counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  currentIndex < sectionNames.length
                      ? _getSectionDisplayName(
                          context, sectionNames[currentIndex])
                      : '',
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.accentIcon,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${currentIndex + 1} / $totalSections',
                style: AppFonts.inter(fontSize: 13, color: palette.muted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Seek slider for scrubbing within the current section
          Semantics(
            label: context.tr(TranslationKeys.guideFeedbackTtsProgress),
            value: '${(shownProgress * 100).round()}%',
            slider: true,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: palette.gold,
                inactiveTrackColor: palette.raised,
                thumbColor: palette.gold,
                overlayColor: palette.gold.withValues(alpha: 0.18),
              ),
              child: Slider(
                value: shownProgress.clamp(0.0, 1.0),
                onChangeStart: (value) {
                  setState(() {
                    _isScrubbing = true;
                    _scrubValue = value;
                  });
                  _ttsService.pause();
                },
                onChanged: (value) {
                  setState(() => _scrubValue = value);
                },
                onChangeEnd: (value) {
                  _ttsService.seekToFraction(value);
                  _ttsService.resume();
                  setState(() => _isScrubbing = false);
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Time labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatTime(elapsedSeconds), style: timeStyle),
              Text(formatTime(estimatedSeconds), style: timeStyle),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required ReaderPalette palette,
    required double size,
    required double iconSize,
    required String semanticLabel,
    bool isPrimary = false,
  }) {
    final isEnabled = onPressed != null;
    final Color fill;
    final Color ink;
    if (isPrimary) {
      fill =
          isEnabled ? palette.ctaFill : palette.ctaFill.withValues(alpha: 0.5);
      ink = palette.ctaInk;
    } else {
      fill = palette.raised;
      ink = isEnabled ? palette.text : palette.dim;
    }

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: isPrimary ? null : Border.all(color: palette.hairline),
          ),
          child: Icon(icon, size: iconSize, color: ink),
        ),
      ),
    );
  }

  Widget _buildSpeedSelector(double currentSpeed, ReaderPalette palette) {
    return Row(
      children: _speedOptions.map((speed) {
        final isSelected = (currentSpeed - speed).abs() < 0.01;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Semantics(
              button: true,
              selected: isSelected,
              child: GestureDetector(
                onTap: () => _ttsService.setSpeechRate(speed),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: isSelected ? palette.selectedFill : palette.raised,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color:
                          isSelected ? palette.selectedFill : palette.hairline,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${speed}x',
                      style: AppFonts.inter(
                        color: isSelected ? palette.onSelected : palette.text,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
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

  Widget _buildSectionList(StudyGuideTtsState state, ReaderPalette palette) {
    final sectionNames = _ttsService.sectionNames;
    final currentIndex = state.currentSectionIndex;
    final isPlaying = state.status == TtsStatus.playing;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: List.generate(sectionNames.length, (index) {
          final isCurrentSection = index == currentIndex;
          final sectionName =
              _getSectionDisplayName(context, sectionNames[index]);

          return Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => _ttsService.skipToSection(index),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isCurrentSection && isPlaying
                      ? palette.gold
                          .withValues(alpha: palette.isDark ? 0.2 : 0.08)
                      : null,
                  border: index < sectionNames.length - 1
                      ? Border(bottom: BorderSide(color: palette.hairline))
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
                            ? palette.gold
                            : (isCurrentSection
                                ? palette.gold.withValues(alpha: 0.25)
                                : Colors.transparent),
                        border: Border.all(
                          color:
                              isCurrentSection ? palette.gold : palette.outline,
                          width: isCurrentSection ? 2 : 1,
                        ),
                      ),
                      child: isCurrentSection && isPlaying
                          ? Icon(
                              Icons.play_arrow,
                              size: 14,
                              color: palette.onGold,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),

                    // Section name
                    Expanded(
                      child: Text(
                        sectionName,
                        style: AppFonts.inter(
                          color: isCurrentSection
                              ? palette.accentIcon
                              : palette.text,
                          fontWeight: isCurrentSection
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: 15,
                        ),
                      ),
                    ),

                    // Skip indicator
                    if (!isCurrentSection)
                      Icon(Icons.chevron_right, size: 20, color: palette.dim),
                  ],
                ),
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
      case 'passage reading':
        return context.tr(TranslationKeys.studyGuidePassageReading);
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
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const TtsControlSheet(),
  );
}
