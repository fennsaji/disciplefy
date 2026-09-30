import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/phone_auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/phone_auth_event.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/phone_auth_state.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/pages/otp_verification_screen.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/pages/phone_number_input_screen.dart';

import '../../helpers/text_fit.dart';
import '../../helpers/welcome_test_harness.dart';

class MockPhoneAuthBloc extends MockBloc<PhoneAuthEvent, PhoneAuthState>
    implements PhoneAuthBloc {}

void main() {
  late MockAuthBloc authBloc;
  late MockPhoneAuthBloc phoneBloc;
  late FakeTranslationService translations;
  late StreamController<PhoneAuthState> phoneStates;

  setUpAll(() async {
    registerFallbackValue(const PhoneAuthResetRequested());
    await loadAppFonts();
  });

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    authBloc = MockAuthBloc();
    whenListen(authBloc, const Stream<AuthState>.empty(),
        initialState: const UnauthenticatedState());
    phoneBloc = MockPhoneAuthBloc();
    phoneStates = StreamController<PhoneAuthState>.broadcast();
    whenListen(phoneBloc, phoneStates.stream,
        initialState: const PhoneAuthInitialState());
  });

  tearDown(() async {
    await phoneStates.close();
    await sl.reset();
  });

  Future<void> pump(WidgetTester tester, Widget screen, String path,
      {required bool dark}) async {
    await tester.pumpWidget(BlocProvider<PhoneAuthBloc>.value(
      value: phoneBloc,
      child: welcomeApp(
        screen: screen,
        path: path,
        dark: dark,
        bloc: authBloc,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Widget otpScreen() => OTPVerificationScreen(
        phoneNumber: '9876543210',
        countryCode: '+91',
        expiresIn: 60,
        sentAt: DateTime.now(),
      );

  /// Unmounts the OTP screen so its countdown timer is cancelled.
  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  for (final dark in [true, false]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('$theme: phone screen shows eyebrow, title, field and CTA',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await pump(tester, const PhoneNumberInputScreen(), '/phone-auth',
          dark: dark);

      expect(find.text('SIGN IN WITH PHONE'), findsOneWidget);
      expect(find.text('Enter your phone number'), findsOneWidget);
      expect(find.byKey(const Key('phone_auth_country_code')), findsOneWidget);
      expect(find.byKey(const Key('phone_auth_number')), findsOneWidget);
      expect(find.text('Secure verification'), findsOneWidget);
      expect(find.text('Send verification code'), findsOneWidget);
    });

    testWidgets('$theme: phone validation, then send requests a code',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await pump(tester, const PhoneNumberInputScreen(), '/phone-auth',
          dark: dark);

      await tester.tap(find.byKey(const Key('phone_auth_send')));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your phone number'), findsOneWidget);
      verifyNever(() => phoneBloc.add(any()));

      await tester.enterText(
          find.byKey(const Key('phone_auth_number')), '5551234567');
      await tester.tap(find.byKey(const Key('phone_auth_send')));
      await tester.pumpAndSettle();
      verify(() => phoneBloc.add(const SendOTPRequested(
          phoneNumber: '5551234567', countryCode: '+1'))).called(1);
    });

    testWidgets('$theme: phone error shows the app snackbar', (tester) async {
      useSurface(tester, const Size(390, 844));
      await pump(tester, const PhoneNumberInputScreen(), '/phone-auth',
          dark: dark);
      phoneStates.add(const PhoneAuthErrorState(message: 'raw'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('raw'), findsNothing);
    });

    testWidgets('$theme: OTP screen shows number, six digits and countdown',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await pump(tester, otpScreen(), '/phone-auth/verify', dark: dark);

      expect(find.text('VERIFY PHONE'), findsOneWidget);
      expect(find.text('Enter verification code'), findsOneWidget);
      expect(find.textContaining('+91 9876543210', findRichText: true),
          findsOneWidget);
      for (var i = 0; i < 6; i++) {
        expect(find.byKey(Key('otp_digit_$i')), findsOneWidget);
      }
      expect(find.textContaining('Code expires in'), findsOneWidget);
      expect(find.byKey(const Key('otp_verify')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('$theme: typing six digits verifies the code', (tester) async {
      useSurface(tester, const Size(390, 844));
      await pump(tester, otpScreen(), '/phone-auth/verify', dark: dark);

      for (var i = 0; i < 6; i++) {
        await tester.enterText(find.byKey(Key('otp_digit_$i')), '${i + 1}');
        await tester.pump();
      }
      verify(() => phoneBloc.add(const VerifyOTPRequested(
            phoneNumber: '9876543210',
            countryCode: '+91',
            otpCode: '123456',
          ))).called(1);
      await unmount(tester);
    });

    for (final language in AppLanguage.values) {
      testWidgets('$theme/${language.code}: phone and OTP fit 320x640',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        translations.language = language;

        await pump(tester, const PhoneNumberInputScreen(), '/phone-auth',
            dark: dark);
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);

        await pump(tester, otpScreen(), '/phone-auth/verify', dark: dark);
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
        await unmount(tester);
      });
    }
  }
}
