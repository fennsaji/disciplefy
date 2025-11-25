import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Settings'),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: () {
                widget.onSave?.call(_preferences);
                Navigator.pop(context, _preferences);
              },
              child: Text(
                'Save',
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
          _buildSectionHeader('Language'),
          _buildLanguagePreference(theme),
          _buildSwitchTile(
            title: 'Auto-detect language',
            subtitle: 'Automatically detect the language you speak',
            value: _preferences.autoDetectLanguage,
            onChanged: (value) => _updatePreference(
              () => _preferences.copyWith(autoDetectLanguage: value),
            ),
          ),
          const Divider(),

          // Voice Section
          _buildSectionHeader('Voice Output'),
          _buildVoiceGenderPreference(theme),
          _buildSliderTile(
            title: 'Speaking Rate',
            subtitle: _getSpeakingRateLabel(_preferences.speakingRate),
            value: _preferences.speakingRate,
            min: 0.5,
            max: 2.0,
            onChanged: (value) => _updatePreference(
              () => _preferences.copyWith(speakingRate: value),
            ),
          ),
          _buildSliderTile(
            title: 'Pitch',
            subtitle: _getPitchLabel(_preferences.pitch),
            value: (_preferences.pitch + 20) / 40, // Normalize -20 to 20 -> 0 to 1
            min: 0.0,
            max: 1.0,
            onChanged: (value) => _updatePreference(
              () => _preferences.copyWith(pitch: (value * 40) - 20),
            ),
          ),
          const Divider(),

          // Interaction Section
          _buildSectionHeader('Interaction'),
          _buildSwitchTile(
            title: 'Auto-play responses',
            subtitle: 'Automatically speak AI responses',
            value: _preferences.autoPlayResponse,
            onChanged: (value) => _updatePreference(
              () => _preferences.copyWith(autoPlayResponse: value),
            ),
          ),
          _buildSwitchTile(
            title: 'Show transcription',
            subtitle: 'Display text while speaking',
            value: _preferences.showTranscription,
            onChanged: (value) => _updatePreference(
              () => _preferences.copyWith(showTranscription: value),
            ),
          ),
          _buildSwitchTile(
            title: 'Continuous mode',
            subtitle: 'Keep listening after response',
            value: _preferences.continuousMode,
            onChanged: (value) => _updatePreference(
              () => _preferences.copyWith(continuousMode: value),
            ),
          ),
          const Divider(),

          // Context Section
          _buildSectionHeader('AI Context'),
          _buildSwitchTile(
            title: 'Use study context',
            subtitle: 'Include your current study for relevant answers',
            value: _preferences.useStudyContext,
            onChanged: (value) => _updatePreference(
              () => _preferences.copyWith(useStudyContext: value),
            ),
          ),
          _buildSwitchTile(
            title: 'Cite Scripture references',
            subtitle: 'Include Bible verse citations in responses',
            value: _preferences.citeScriptureReferences,
            onChanged: (value) => _updatePreference(
              () => _preferences.copyWith(citeScriptureReferences: value),
            ),
          ),
          const Divider(),

          // Notifications Section
          _buildSectionHeader('Notifications'),
          _buildSwitchTile(
            title: 'Quota alerts',
            subtitle: 'Notify when daily conversation limit is reached',
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
              child: const Text('Reset to Defaults'),
            ),
          ),
          const SizedBox(height: 32),
        ],
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
      orElse: () => VoiceLanguage.english,
    );

    return ListTile(
      title: const Text('Preferred language'),
      subtitle: Text(currentLanguage.displayName),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showLanguageSelector(theme),
    );
  }

  void _showLanguageSelector(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Language',
                style: theme.textTheme.titleMedium,
              ),
            ),
            ...VoiceLanguage.values.map((language) {
              final isSelected = language.code == _preferences.preferredLanguage;
              return ListTile(
                title: Text(language.displayName),
                trailing: isSelected
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : null,
                onTap: () {
                  _updatePreference(
                    () => _preferences.copyWith(preferredLanguage: language.code),
                  );
                  Navigator.pop(context);
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
      title: const Text('Voice gender'),
      subtitle: Text(_preferences.ttsVoiceGender == VoiceGender.female
          ? 'Female'
          : 'Male'),
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
    if (rate < 0.75) return 'Very Slow';
    if (rate < 1.0) return 'Slow';
    if (rate < 1.25) return 'Normal';
    if (rate < 1.5) return 'Fast';
    return 'Very Fast';
  }

  String _getPitchLabel(double pitch) {
    if (pitch < -10) return 'Very Low';
    if (pitch < -5) return 'Low';
    if (pitch < 5) return 'Normal';
    if (pitch < 10) return 'High';
    return 'Very High';
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings?'),
        content: const Text(
          'This will reset all voice settings to their default values. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _preferences = VoicePreferencesEntity.defaults(
                  _preferences.userId,
                );
                _hasChanges = true;
              });
            },
            child: Text(
              'Reset',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
