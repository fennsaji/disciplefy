import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/domain/repositories/voice_buddy_repository.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_preferences_bloc.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_preferences_event.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_preferences_state.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/pages/voice_preferences_page.dart';

/// Wrapper widget that provides VoicePreferencesBloc to VoicePreferencesPage
class VoicePreferencesPageWrapper extends StatefulWidget {
  /// Bloc to use instead of creating one from the service locator (tests).
  final VoicePreferencesBloc? bloc;

  const VoicePreferencesPageWrapper({super.key, this.bloc});

  @override
  State<VoicePreferencesPageWrapper> createState() =>
      _VoicePreferencesPageWrapperState();
}

class _VoicePreferencesPageWrapperState
    extends State<VoicePreferencesPageWrapper> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final content = BlocConsumer<VoicePreferencesBloc, VoicePreferencesState>(
      listener: (context, state) {
        // When save completes successfully, pop the page
        if (state is VoicePreferencesSaved && _isSaving) {
          _isSaving = false;
          Navigator.pop(context, state.preferences);
        }
      },
      builder: (context, state) {
        if (state is VoicePreferencesLoaded ||
            state is VoicePreferencesSaving) {
          final preferences = state is VoicePreferencesLoaded
              ? state.preferences
              : (state as VoicePreferencesSaving).preferences;
          return VoicePreferencesPage(
            initialPreferences: preferences,
            isSaving: state is VoicePreferencesSaving,
            onSave: (prefs) {
              setState(() => _isSaving = true);
              context.read<VoicePreferencesBloc>().add(
                    UpdateVoicePreferences(prefs),
                  );
            },
          );
        } else if (state is VoicePreferencesError) {
          return _StatusScaffold(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr(TranslationKeys.commonErrorTryAgain),
                  textAlign: TextAlign.center,
                  style: AppFonts.inter(
                    fontSize: 14.5,
                    color: ReaderPalette.of(context).muted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                SettingsButton(
                  label: context.tr(TranslationKeys.commonRetry),
                  icon: Icons.refresh_rounded,
                  onPressed: () {
                    context.read<VoicePreferencesBloc>().add(
                          const LoadVoicePreferences(),
                        );
                  },
                ),
              ],
            ),
          );
        }

        // Loading state
        return const _StatusScaffold(child: CircularProgressIndicator());
      },
    );

    final injected = widget.bloc;
    if (injected != null) {
      return BlocProvider.value(value: injected, child: content);
    }
    return BlocProvider(
      create: (_) => VoicePreferencesBloc(
        repository: sl<VoiceBuddyRepository>(),
      )..add(const LoadVoicePreferences()),
      child: content,
    );
  }
}

/// Voice settings chrome around a centred loading or error body.
class _StatusScaffold extends StatelessWidget {
  final Widget child;

  const _StatusScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ReaderPalette.of(context).page,
      appBar: SettingsTopBar(title: context.tr('voice_buddy.settings.title')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: child,
        ),
      ),
    );
  }
}
