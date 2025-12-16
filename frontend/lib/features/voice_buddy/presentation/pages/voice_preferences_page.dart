import 'package:flutter/material.dart';

import '../../../../core/extensions/translation_extension.dart';
import '../../domain/entities/voice_preferences_entity.dart';
import '../widgets/language_selector.dart';

/// Page for managing voice buddy preferences.
class VoicePreferencesPage extends StatefulWidget {
  final VoicePreferencesEntity initialPreferences;
  final void Function(VoicePreferencesEntity preferences)? onSave;

  const VoicePreferencesPage({
    super.key,
    required this.initialPreferences,
    this.onSave,
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

  Future<bool> _onWillPop() async {
    if (!_hasChanges) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('voice_buddy.settings.unsaved_title')),
        content: Text(context.tr('voice_buddy.settings.unsaved_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true), // Discard
            child: Text(context.tr('voice_buddy.settings.discard')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false), // Cancel
            child: Text(context.tr('voice_buddy.conversation.cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(
                  dialogContext, false); // Close dialog, don't pop page yet
              // onSave triggers bloc save, wrapper will pop when complete
              widget.onSave?.call(_preferences);
            },
            child: Text(
              context.tr('voice_buddy.settings.save'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        appBar: AppBar(
          title: Text(context.tr('voice_buddy.settings.title')),
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: () {
                  // onSave triggers the bloc to save, and the wrapper
                  // will pop the page when save completes
                  widget.onSave?.call(_preferences);
                },
                child: Text(
                  context.tr('voice_buddy.settings.save'),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        body: ListView(
          children: [
            // Language Section
            _buildSectionHeader(
                context.tr('voice_buddy.settings.language_section')),
            _buildLanguagePreference(theme),
            _buildSwitchTile(
              title: context.tr('voice_buddy.settings.auto_detect'),
              subtitle: context.tr('voice_buddy.settings.auto_detect_subtitle'),
              value: _preferences.autoDetectLanguage,
              onChanged: (value) => _updatePreference(
                () => _preferences.copyWith(autoDetectLanguage: value),
              ),
            ),
            const Divider(),

            // Voice Section
            _buildSectionHeader(
                context.tr('voice_buddy.settings.voice_output')),
            _buildVoiceGenderPreference(theme),
            _buildSliderTile(
              title: context.tr('voice_buddy.settings.speaking_rate'),
              subtitle: _getSpeakingRateLabel(_preferences.speakingRate),
              value: _preferences.speakingRate,
              min: 0.5,
              max: 2.0,
              onChanged: (value) => _updatePreference(
                () => _preferences.copyWith(speakingRate: value),
              ),
            ),
            _buildSliderTile(
              title: context.tr('voice_buddy.settings.pitch'),
              subtitle: _getPitchLabel(_preferences.pitch),
              value: (_preferences.pitch + 20) /
                  40, // Normalize -20 to 20 -> 0 to 1
              min: 0.0,
              max: 1.0,
              onChanged: (value) => _updatePreference(
                () => _preferences.copyWith(pitch: (value * 40) - 20),
              ),
            ),
            const Divider(),

            // Interaction Section
            _buildSectionHeader(context.tr('voice_buddy.settings.interaction')),
            _buildSwitchTile(
              title: context.tr('voice_buddy.settings.auto_play'),
              subtitle: context.tr('voice_buddy.settings.auto_play_subtitle'),
              value: _preferences.autoPlayResponse,
              onChanged: (value) => _updatePreference(
                () => _preferences.copyWith(autoPlayResponse: value),
              ),
            ),
            _buildSwitchTile(
              title: context.tr('voice_buddy.settings.show_transcription'),
              subtitle: context
                  .tr('voice_buddy.settings.show_transcription_subtitle'),
              value: _preferences.showTranscription,
              onChanged: (value) => _updatePreference(
                () => _preferences.copyWith(showTranscription: value),
              ),
            ),
            _buildSwitchTile(
              title: context.tr('voice_buddy.settings.continuous_mode'),
              subtitle:
                  context.tr('voice_buddy.settings.continuous_mode_subtitle'),
              value: _preferences.continuousMode,
              onChanged: (value) => _updatePreference(
                () => _preferences.copyWith(continuousMode: value),
              ),
            ),
            const Divider(),

            // Notifications Section
            _buildSectionHeader(
                context.tr('voice_buddy.settings.notifications')),
            _buildSwitchTile(
              title: context.tr('voice_buddy.settings.quota_alerts'),
              subtitle:
                  context.tr('voice_buddy.settings.quota_alerts_subtitle'),
              value: _preferences.notifyDailyQuotaReached,
              onChanged: (value) => _updatePreference(
                () => _preferences.copyWith(notifyDailyQuotaReached: value),
              ),
            ),
            const SizedBox(height: 32),

            // Reset Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton(
                onPressed: _showResetConfirmation,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                ),
                child: Text(context.tr('voice_buddy.settings.reset_defaults')),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLanguagePreference(ThemeData theme) {
    final currentLanguage = VoiceLanguage.values.firstWhere(
      (lang) => lang.code == _preferences.preferredLanguage,
      orElse: () => VoiceLanguage.defaultLang,
    );

    // Build subtitle based on whether it's default or a specific language
    final subtitle = currentLanguage.isDefault
        ? context.tr('voice_buddy.settings.default_language_subtitle')
        : currentLanguage.displayName;

    return ListTile(
      title: Text(context.tr('voice_buddy.settings.preferred_language')),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showLanguageSelector(theme),
    );
  }

  void _showLanguageSelector(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.tr('voice_buddy.settings.select_language'),
                style: theme.textTheme.titleMedium,
              ),
            ),
            ...VoiceLanguage.values.map((language) {
              final isSelected =
                  language.code == _preferences.preferredLanguage;
              return ListTile(
                leading: Text(
                  language.flag,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(
                  language.isDefault
                      ? context.tr('voice_buddy.settings.default_language')
                      : language.displayName,
                ),
                subtitle: language.isDefault
                    ? Text(
                        context.tr(
                            'voice_buddy.settings.default_language_subtitle'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : null,
                trailing: isSelected
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : null,
                onTap: () {
                  _updatePreference(
                    () =>
                        _preferences.copyWith(preferredLanguage: language.code),
                  );
                  Navigator.pop(sheetContext);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceGenderPreference(ThemeData theme) {
    return ListTile(
      title: Text(context.tr('voice_buddy.settings.voice_gender')),
      subtitle: Text(_preferences.ttsVoiceGender == VoiceGender.female
          ? context.tr('voice_buddy.settings.female')
          : context.tr('voice_buddy.settings.male')),
      trailing: SegmentedButton<VoiceGender>(
        segments: const [
          ButtonSegment(
            value: VoiceGender.female,
            icon: Icon(Icons.face_3),
          ),
          ButtonSegment(
            value: VoiceGender.male,
            icon: Icon(Icons.face),
          ),
        ],
        selected: {_preferences.ttsVoiceGender},
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) {
            _updatePreference(
              () => _preferences.copyWith(ttsVoiceGender: selection.first),
            );
          }
        },
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: theme.colorScheme.primary,
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
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('voice_buddy.settings.reset_title')),
        content: Text(context.tr('voice_buddy.settings.reset_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('voice_buddy.conversation.cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() {
                _preferences = VoicePreferencesEntity.defaults(
                  _preferences.userId,
                );
                _hasChanges = true;
              });
            },
            child: Text(
              context.tr('voice_buddy.settings.reset_button'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
