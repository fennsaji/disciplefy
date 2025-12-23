import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../data/services/study_guide_tts_service.dart';
import '../../domain/entities/study_guide.dart';
import '../../domain/entities/study_mode.dart';

/// A button widget for controlling TTS playback of study guides.
///
/// Displays different states (idle, loading, playing, paused) with
/// appropriate icons and labels. Supports tap for play/pause toggle.
/// When playing/paused, shows a settings icon that opens advanced controls
/// via [onControlsTap].
class TtsControlButton extends StatefulWidget {
  final StudyGuide guide;

  /// Study mode for mode-specific section titles
  final StudyMode mode;

  /// Callback invoked when the user taps the controls/settings icon
  /// (visible when playing or paused).
  final VoidCallback? onControlsTap;

  const TtsControlButton({
    super.key,
    required this.guide,
    this.mode = StudyMode.standard,
    this.onControlsTap,
  });

  @override
  State<TtsControlButton> createState() => _TtsControlButtonState();
}

class _TtsControlButtonState extends State<TtsControlButton> {
  late final StudyGuideTTSService _ttsService;

  @override
  void initState() {
    super.initState();
    _ttsService = sl<StudyGuideTTSService>();
  }

  @override
  void dispose() {
    // Don't dispose the service here as it's a singleton
    super.dispose();
  }

  void _handleTap() {
    final status = _ttsService.state.value.status;

    if (status == TtsStatus.idle || status == TtsStatus.error) {
      // Start reading from the beginning with mode-specific section titles
      _ttsService.startReading(widget.guide, mode: widget.mode);
    } else {
      // Toggle play/pause
      _ttsService.togglePlayPause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StudyGuideTtsState>(
      valueListenable: _ttsService.state,
      builder: (context, state, child) {
        return _buildButton(context, state);
      },
    );
  }

  Widget _buildButton(BuildContext context, StudyGuideTtsState state) {
    final IconData icon;
    final String label;
    final bool isLoading;
    final bool showControls;

    switch (state.status) {
      case TtsStatus.idle:
      case TtsStatus.error:
        icon = Icons.headphones;
        label = context.tr(TranslationKeys.studyGuideListen);
        isLoading = false;
        showControls = false;
        break;
      case TtsStatus.loading:
        icon = Icons.headphones;
        label = context.tr(TranslationKeys.studyGuideLoading);
        isLoading = true;
        showControls = false;
        break;
      case TtsStatus.playing:
        icon = Icons.pause_circle_filled;
        label = context.tr(TranslationKeys.studyGuidePause);
        isLoading = false;
        showControls = true;
        break;
      case TtsStatus.paused:
        icon = Icons.play_circle_filled;
        label = context.tr(TranslationKeys.studyGuideResume);
        isLoading = false;
        showControls = true;
        break;
    }

    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          children: [
            // Main play/pause button
            Expanded(
              child: InkWell(
                onTap: _handleTap,
                borderRadius: BorderRadius.horizontal(
                  left: const Radius.circular(16),
                  right: showControls ? Radius.zero : const Radius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      else
                        Icon(
                          icon,
                          color: Colors.white,
                          size: 20,
                        ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Controls button (visible when playing/paused)
            if (showControls) ...[
              Container(
                width: 1,
                height: 32,
                color: Colors.white.withOpacity(0.3),
              ),
              InkWell(
                onTap: widget.onControlsTap,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(
                    Icons.tune,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
