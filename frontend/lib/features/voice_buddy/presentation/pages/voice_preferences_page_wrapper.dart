import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../domain/repositories/voice_buddy_repository.dart';
import '../bloc/voice_preferences_bloc.dart';
import '../bloc/voice_preferences_event.dart';
import '../bloc/voice_preferences_state.dart';
import 'voice_preferences_page.dart';

/// Wrapper widget that provides VoicePreferencesBloc to VoicePreferencesPage
class VoicePreferencesPageWrapper extends StatelessWidget {
  const VoicePreferencesPageWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => VoicePreferencesBloc(
        repository: sl<VoiceBuddyRepository>(),
      )..add(const LoadVoicePreferences()),
      child: BlocBuilder<VoicePreferencesBloc, VoicePreferencesState>(
        builder: (context, state) {
          if (state is VoicePreferencesLoaded) {
            return VoicePreferencesPage(
              initialPreferences: state.preferences,
              onSave: (preferences) {
                context.read<VoicePreferencesBloc>().add(
                      UpdateVoicePreferences(preferences),
                    );
              },
            );
          } else if (state is VoicePreferencesError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Voice Settings')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${state.message}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<VoicePreferencesBloc>().add(
                              const LoadVoicePreferences(),
                            );
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Loading state
          return Scaffold(
            appBar: AppBar(title: const Text('Voice Settings')),
            body: const Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}
