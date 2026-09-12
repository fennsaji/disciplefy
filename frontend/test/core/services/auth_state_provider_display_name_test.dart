import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/services/auth_state_provider.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart';

import 'auth_state_provider_display_name_test.mocks.dart';

/// The name-edit dialog in Settings prefills from this getter. It must never
/// offer a fabricated value — the email-derived guess, or the literal 'User'
/// — as if the user had actually set it: someone who has never set a name
/// would otherwise save that guess back as their real one.
@GenerateMocks([AuthBloc])
void main() {
  late MockAuthBloc bloc;
  late AuthStateProvider provider;

  User userWith({Map<String, dynamic>? metadata}) => User(
        id: 'u-1',
        appMetadata: const {},
        userMetadata: metadata,
        aud: 'authenticated',
        createdAt: DateTime(2026).toIso8601String(),
        email: 'langtest@example.com',
      );

  setUp(() {
    bloc = MockAuthBloc();
    when(bloc.stream).thenAnswer((_) => const Stream.empty());
    provider = AuthStateProvider();
  });

  test('a name from user metadata is used to prefill', () {
    when(bloc.state).thenReturn(
      AuthenticatedState(user: userWith(metadata: {'full_name': 'Fenn Saji'})),
    );
    provider.initialize(bloc);

    expect(provider.profileBasedDisplayNameOrEmpty, 'Fenn Saji');
  });

  test('no metadata name means an empty prefill, not the email', () {
    when(bloc.state).thenReturn(AuthenticatedState(user: userWith()));
    provider.initialize(bloc);

    expect(provider.profileBasedDisplayNameOrEmpty, '');
    // The ordinary getter is allowed to fall back to the email locally-part —
    // it is a display value, not something ever written back as a name.
    expect(provider.profileBasedDisplayName, isNot(''));
  });

  test('blank metadata is treated the same as absent', () {
    when(bloc.state).thenReturn(
      AuthenticatedState(user: userWith(metadata: {'full_name': '   '})),
    );
    provider.initialize(bloc);

    expect(provider.profileBasedDisplayNameOrEmpty, '');
  });

  test('unauthenticated has no name to prefill', () {
    when(bloc.state).thenReturn(const UnauthenticatedState());
    provider.initialize(bloc);

    expect(provider.profileBasedDisplayNameOrEmpty, '');
  });
}
