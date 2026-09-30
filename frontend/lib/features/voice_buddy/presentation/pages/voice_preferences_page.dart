import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/domain/entities/voice_preferences_entity.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/language_selector.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

/// Page for managing voice buddy preferences.
///
/// Edits are kept locally until the user taps Save (top bar, or the
/// unsaved-changes dialog on leaving); [onSave] hands them to the caller.
class VoicePreferencesPage extends StatefulWidget {
  final VoicePreferencesEntity initialPreferences;
  final void Function(VoicePreferencesEntity preferences)? onSave;

  /// Whether a save is in flight: the Save action shows a spinner and
  /// ignores taps.
  final bool isSaving;

  const VoicePreferencesPage({
    super.key,
    required this.initialPreferences,
    this.onSave,
    this.isSaving = false,
  });

  @override
  State<VoicePreferencesPage> createState() => _VoicePreferencesPageState();
}

class _VoicePreferencesPageState extends State<VoicePreferencesPage> {
  late VoicePreferencesEntity _preferences;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _preferences = widget.initialPreferences;
  }

  void _updatePreference(VoicePreferencesEntity Function() update) {
    setState(() {
      _preferences = update();
      _hasChanges = true;
    });
  }

  void _save() => widget.onSave?.call(_preferences);

  /// Asks what to do with unsaved edits. Resolves true when the page may
  /// close (Discard); Cancel and Save keep it open — after Save the wrapper
  /// pops the page once the save completes.
  Future<bool> _onWillPop() async {
    if (!_hasChanges) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => PopupDialog(
        children: [
          PopupHeader(
            icon: const PopupIconCircle(icon: Icons.edit_note_rounded),
            title: context.tr('voice_buddy.settings.unsaved_title'),
            body: context.tr('voice_buddy.settings.unsaved_message'),
          ),
          const SizedBox(height: 22),
          PopupPrimaryButton(
            label: context.tr('voice_buddy.settings.save'),
            onPressed: () {
              // Close dialog, don't pop page yet: onSave triggers the bloc
              // save and the wrapper pops when it completes.
              Navigator.pop(dialogContext, false);
              _save();
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SettingsButton(
              label: context.tr('voice_buddy.settings.discard'),
              kind: SettingsButtonKind.destructive,
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ),
          const SizedBox(height: 4),
          PopupTextButton(
            label: context.tr('voice_buddy.conversation.cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: palette.page,
        appBar: SettingsTopBar(
          title: context.tr('voice_buddy.settings.title'),
        ),
        // Save sits in a bar under the list (not the top bar) so a long
        // hi/ml label never squeezes the title.
        bottomNavigationBar: _hasChanges
            ? _SaveBar(saving: widget.isSaving, onSave: _save)
            : null,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            // Language
            SettingsSectionLabel(
                context.tr('voice_buddy.settings.language_section')),
            SettingsGroup(
              children: [
                _buildLanguageRow(),
                _ToggleRow(
                  icon: Icons.center_focus_weak_rounded,
                  title: context.tr('voice_buddy.settings.auto_detect'),
                  subtitle:
                      context.tr('voice_buddy.settings.auto_detect_subtitle'),
                  value: _preferences.autoDetectLanguage,
                  onChanged: (value) => _updatePreference(
                    () => _preferences.copyWith(autoDetectLanguage: value),
                  ),
                ),
              ],
            ),

            // Voice output
            SettingsSectionLabel(
                context.tr('voice_buddy.settings.voice_output')),
            SettingsGroup(
              children: [
                _buildVoiceGender(),
                _SliderRow(
                  title: context.tr('voice_buddy.settings.speaking_rate'),
                  valueLabel: _getSpeakingRateLabel(_preferences.speakingRate),
                  value: _preferences.speakingRate,
                  min: 0.5,
                  max: 2.0,
                  onChanged: (value) => _updatePreference(
                    () => _preferences.copyWith(speakingRate: value),
                  ),
                ),
                _SliderRow(
                  title: context.tr('voice_buddy.settings.pitch'),
                  valueLabel: _getPitchLabel(_preferences.pitch),
                  // Normalize -20..20 to 0..1.
                  value: (_preferences.pitch + 20) / 40,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (value) => _updatePreference(
                    () => _preferences.copyWith(pitch: (value * 40) - 20),
                  ),
                ),
              ],
            ),

            // Interaction
            SettingsSectionLabel(
                context.tr('voice_buddy.settings.interaction')),
            SettingsGroup(
              children: [
                _ToggleRow(
                  title: context.tr('voice_buddy.settings.auto_play'),
                  subtitle:
                      context.tr('voice_buddy.settings.auto_play_subtitle'),
                  value: _preferences.autoPlayResponse,
                  onChanged: (value) => _updatePreference(
                    () => _preferences.copyWith(autoPlayResponse: value),
                  ),
                ),
                _ToggleRow(
                  title: context.tr('voice_buddy.settings.show_transcription'),
                  subtitle: context
                      .tr('voice_buddy.settings.show_transcription_subtitle'),
                  value: _preferences.showTranscription,
                  onChanged: (value) => _updatePreference(
                    () => _preferences.copyWith(showTranscription: value),
                  ),
                ),
                _ToggleRow(
                  title: context.tr('voice_buddy.settings.continuous_mode'),
                  subtitle: context
                      .tr('voice_buddy.settings.continuous_mode_subtitle'),
                  value: _preferences.continuousMode,
                  onChanged: (value) => _updatePreference(
                    () => _preferences.copyWith(continuousMode: value),
                  ),
                ),
              ],
            ),

            // Study memory
            SettingsSectionLabel(context.tr('voice_buddy.settings.ai_context')),
            SettingsGroup(
              children: [
                _ToggleRow(
                  title: context.tr('voice_buddy.settings.use_study_context'),
                  subtitle: context
                      .tr('voice_buddy.settings.use_study_context_subtitle'),
                  value: _preferences.useStudyContext,
                  onChanged: (value) => _updatePreference(
                    () => _preferences.copyWith(useStudyContext: value),
                  ),
                ),
                _ToggleRow(
                  title: context.tr('voice_buddy.settings.cite_scripture'),
                  subtitle: context
                      .tr('voice_buddy.settings.cite_scripture_subtitle'),
                  value: _preferences.citeScriptureReferences,
                  onChanged: (value) => _updatePreference(
                    () => _preferences.copyWith(citeScriptureReferences: value),
                  ),
                ),
              ],
            ),

            // Notifications
            SettingsSectionLabel(
                context.tr('voice_buddy.settings.notifications')),
            SettingsGroup(
              children: [
                _ToggleRow(
                  title: context.tr('voice_buddy.settings.quota_alerts'),
                  subtitle:
                      context.tr('voice_buddy.settings.quota_alerts_subtitle'),
                  value: _preferences.notifyDailyQuotaReached,
                  onChanged: (value) => _updatePreference(
                    () => _preferences.copyWith(notifyDailyQuotaReached: value),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            SettingsGroup(
              children: [
                SettingsRow(
                  icon: Icons.restart_alt_rounded,
                  title: context.tr('voice_buddy.settings.reset_defaults'),
                  destructive: true,
                  onTap: _showResetConfirmation,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageRow() {
    final currentLanguage = VoiceLanguage.values.firstWhere(
      (lang) => lang.code == _preferences.preferredLanguage,
      orElse: () => VoiceLanguage.defaultLang,
    );

    return SettingsRow(
      icon: Icons.language_rounded,
      title: context.tr('voice_buddy.settings.preferred_language'),
      subtitle: currentLanguage.isDefault
          ? context.tr('voice_buddy.settings.default_language_subtitle')
          : null,
      value: currentLanguage.isDefault
          ? context.tr('voice_buddy.settings.default_language')
          : currentLanguage.displayName,
      onTap: () => _showLanguageSelector(currentLanguage),
    );
  }

  Future<void> _showLanguageSelector(VoiceLanguage current) async {
    final picked = await VoiceLanguageSheet.show(
      context,
      selectedLanguage: current,
    );
    if (picked == null || !mounted) return;
    _updatePreference(
      () => _preferences.copyWith(preferredLanguage: picked.code),
    );
  }

  Widget _buildVoiceGender() {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('voice_buddy.settings.voice_gender'),
            style: AppFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: palette.text,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          _GenderSegments(
            selected: _preferences.ttsVoiceGender,
            femaleLabel: context.tr('voice_buddy.settings.female'),
            maleLabel: context.tr('voice_buddy.settings.male'),
            onChanged: (gender) => _updatePreference(
              () => _preferences.copyWith(ttsVoiceGender: gender),
            ),
          ),
        ],
      ),
    );
  }

  String _getSpeakingRateLabel(double rate) {
    if (rate < 0.75) {
      return context.tr('voice_buddy.settings.speaking_rate_very_slow');
    }
    if (rate < 1.0) {
      return context.tr('voice_buddy.settings.speaking_rate_slow');
    }
    if (rate < 1.25) {
      return context.tr('voice_buddy.settings.speaking_rate_normal');
    }
    if (rate < 1.5) {
      return context.tr('voice_buddy.settings.speaking_rate_fast');
    }
    return context.tr('voice_buddy.settings.speaking_rate_very_fast');
  }

  String _getPitchLabel(double pitch) {
    if (pitch < -10) return context.tr('voice_buddy.settings.pitch_very_low');
    if (pitch < -5) return context.tr('voice_buddy.settings.pitch_low');
    if (pitch < 5) return context.tr('voice_buddy.settings.pitch_normal');
    if (pitch < 10) return context.tr('voice_buddy.settings.pitch_high');
    return context.tr('voice_buddy.settings.pitch_very_high');
  }

  void _showResetConfirmation() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => PopupDialog(
        children: [
          PopupHeader(
            icon: const _RedIconCircle(icon: Icons.restart_alt_rounded),
            title: context.tr('voice_buddy.settings.reset_title'),
            body: context.tr('voice_buddy.settings.reset_message'),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: SettingsButton(
              label: context.tr('voice_buddy.settings.reset_button'),
              kind: SettingsButtonKind.destructive,
              onPressed: () {
                Navigator.pop(dialogContext);
                setState(() {
                  _preferences = VoicePreferencesEntity.defaults(
                    _preferences.userId,
                  );
                  _hasChanges = true;
                });
              },
            ),
          ),
          const SizedBox(height: 4),
          PopupTextButton(
            label: context.tr('voice_buddy.conversation.cancel'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }
}

/// Full-width indigo Save pill pinned under the list; a spinner while
/// saving.
class _SaveBar extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;

  const _SaveBar({required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.page,
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SettingsButton(
            label: context.tr('voice_buddy.settings.save'),
            loading: saving,
            onPressed: onSave,
          ),
        ),
      ),
    );
  }
}

/// Soft red circle for the destructive reset dialog.
class _RedIconCircle extends StatelessWidget {
  final IconData icon;

  const _RedIconCircle({required this.icon});

  @override
  Widget build(BuildContext context) {
    final red = SettingsToneColors.of(context, SettingsTone.red);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(color: red.fill, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, size: 26, color: red.foreground),
    );
  }
}

/// Title, subtitle and a switch; the whole row toggles. An optional leading
/// [icon] tile lines it up with [SettingsRow]s in the same group.
class _ToggleRow extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (icon != null) ...[
                  SettingsIconTile(icon: icon!),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: palette.text,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppFonts.inter(
                          fontSize: 12,
                          color: palette.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SettingsSwitch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Title with its current value label on the right, and a slider below.
class _SliderRow extends StatelessWidget {
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: palette.text,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Sits at the row's right edge, like a settings row value;
              // capped so a long translation wraps rather than squeezing
              // the title.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  valueLabel,
                  textAlign: TextAlign.end,
                  style: AppFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: palette.accentIcon,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: settingsPrimaryFill,
              inactiveTrackColor:
                  palette.isDark ? palette.raised : const Color(0xFFE2E2E8),
              thumbColor: Colors.white,
              overlayColor: settingsPrimaryFill.withValues(alpha: 0.12),
              thumbShape: const _RingThumbShape(),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              // No default side inset: the track spans the same content
              // width as the title row above it.
              padding: const EdgeInsets.symmetric(vertical: 14),
              value: value.clamp(min, max),
              min: min,
              max: max,
              semanticFormatterCallback: (_) => valueLabel,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// White slider thumb with an indigo ring.
class _RingThumbShape extends SliderComponentShape {
  static const double _radius = 10;

  const _RingThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, _radius, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      _radius - 1,
      Paint()
        ..color = settingsPrimaryFill
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

/// Two-option pill control for the TTS voice. Each option wraps its label
/// rather than cutting it.
class _GenderSegments extends StatelessWidget {
  final VoiceGender selected;
  final String femaleLabel;
  final String maleLabel;
  final ValueChanged<VoiceGender> onChanged;

  const _GenderSegments({
    required this.selected,
    required this.femaleLabel,
    required this.maleLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    Widget segment(VoiceGender gender, String label) {
      final isSelected = gender == selected;
      return Expanded(
        child: Semantics(
          selected: isSelected,
          inMutuallyExclusiveGroup: true,
          button: true,
          child: Material(
            color: isSelected ? palette.ctaFill : Colors.transparent,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onChanged(gender),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Center(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? palette.ctaInk : palette.muted,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(999),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            segment(VoiceGender.female, femaleLabel),
            segment(VoiceGender.male, maleLabel),
          ],
        ),
      ),
    );
  }
}
