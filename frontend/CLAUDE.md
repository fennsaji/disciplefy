# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See also the root `../CLAUDE.md` for project-wide architecture, backend details, and cross-cutting patterns.

## Commands

```bash
sh scripts/run-web-local.sh          # Run web dev server (port 59641, requires .env.local)
sh scripts/run-android-local.sh      # Run on Android device/emulator
flutter pub get                      # Install dependencies
flutter analyze                      # Lint (uses analysis_options.yaml)
dart format lib/                     # Format
flutter test                         # Run all tests
flutter test test/features/auth/auth_service_test.dart  # Run single test
dart run build_runner build --delete-conflicting-outputs  # Regenerate .g.dart / .mocks.dart
```

Environment variables are injected via `--dart-define` at build time. The run scripts read from `.env.local` (gitignored). Never hardcode secrets — use `AppConfig` (`lib/core/config/app_config.dart`) which reads `String.fromEnvironment(...)`.

## Architecture

### Feature Module Structure

Every feature in `lib/features/` has three layers with strict dependency direction (Presentation -> Domain <- Data):

- **domain/** — Pure Dart: entities, repository interfaces (`abstract class`), use cases extending `UseCase<Type, Params>` from `core/usecases/usecase.dart`. Returns `Future<Either<Failure, T>>` using `dartz`.
- **data/** — Implements domain interfaces: repository impls, remote/local datasources, JSON models (extend domain entities).
- **presentation/** — BLoC (events/states/bloc), pages, widgets. Only depends on domain.

### Dependency Injection

All wiring in `lib/core/di/injection_container.dart` using GetIt. Access via `sl<T>()`.

- BLoCs are registered as `LazySingleton` (long-lived, shared across screens)
- Use cases as `Factory` (new instance per call)
- Repos and datasources as `LazySingleton`

When adding a new feature: register datasource -> repository -> use cases -> BLoC in `injection_container.dart`, then provide BLoC in `main.dart`'s `MultiBlocProvider` if it needs app-wide scope.

### State Management (BLoC)

All state management uses `flutter_bloc`. Pattern:
- Events: sealed/abstract class extending `Equatable`
- States: abstract class extending `Equatable` with typed subclasses (e.g., `Loading`, `Loaded`, `Error`)
- BLoC: registers `on<EventType>` handlers in constructor

Complex BLoCs delegate to handler classes (e.g., `StudyBloc` uses `GenerationHandler`, `SaveHandler`, `ValidationHandler`).

Global BLoCs provided at app root in `main.dart`: `AuthBloc`, `StudyBloc`, `DailyVerseBloc`, `SettingsBloc`, `TokenBloc`, `ConnectivityBloc`, `GamificationBloc`, `FeedbackBloc`, `NotificationBloc`, `SubscriptionBloc`.

### Routing

`go_router` configured in `lib/core/router/app_router.dart`. Routes defined as constants in `app_routes.dart`.

- `AppShell` (`lib/core/presentation/widgets/app_shell.dart`) wraps bottom-tab navigation using `StatefulNavigationShell` with `IndexedStack` persistence
- `RouterGuard` handles auth redirects — checks Supabase session, onboarding status, language selection
- `AuthNotifier` listens to `supabase.auth.onAuthStateChange` and triggers router refresh

### Error Handling

Use typed `Failure` subclasses from `lib/core/error/failures.dart`: `ServerFailure`, `NetworkFailure`, `ValidationFailure`, `AuthenticationFailure`, `AuthorizationFailure`, `StorageFailure`, `RateLimitFailure`, `CacheFailure`, `NotFoundFailure`, `PaymentFailure`, `TokenFailure`.

Repositories catch exceptions and return `Left(XFailure(...))`. Presentation layer pattern-matches on failure type.

### Logging

`print()` is banned by lint rules. Use `Logger` from `lib/core/utils/logger.dart`:
```dart
Logger.debug('message');
Logger.info('message');
Logger.warning('message');
Logger.error('message', error: e, stackTrace: s);
```

## Key Conventions

- **Package imports only**: `import 'package:disciplefy_bible_study/...'` — no relative imports
- **Either monad**: All use cases return `Future<Either<Failure, T>>` — fold in presentation to handle success/error
- **Platform-conditional imports**: Use the `if (dart.library.html)` pattern for web-only code (see `notification_service_web_stub.dart`)
- **Android hybrid storage**: `AndroidHybridStorage` combines `flutter_secure_storage` + `SharedPreferences` fallback for Android Keystore reliability
- **Max content width**: App caps at 900px on wide screens (set in `MaterialApp.router` builder in `main.dart`)
- **Fonts**: Bundled `Inter` (body) and `Poppins` (headings) — not fetched from Google Fonts
- **Colors**: Use `AppColors` from `lib/core/constants/app_colors.dart` or `AppColorsTheme` context extension. Material 3 enabled.
- **Localization**: 3 languages (en, hi, ml) via `AppLocalizations`. Translation keys in `lib/core/i18n/`.

## Testing

Tests mirror `lib/` structure under `test/`. Conventions:
- Mocks: `@GenerateMocks([...])` annotation + `dart run build_runner build` to generate `.mocks.dart` files
- BLoC tests: use `bloc_test` package (`blocTest()` helper, `whenListen()`)
- Widget tests: `flutter_test` with `pumpWidget()`, wrap in `MaterialApp` + `BlocProvider` as needed
- Use `test/helpers/mock_translation_provider.dart` for localization in widget tests
- AAA pattern: Arrange (`when(...)`) / Act (add event or call method) / Assert (`expect`, `verify`)

## Code Generation

Uses `build_runner` for:
- `retrofit_generator` — REST client interfaces (`.g.dart`)
- `json_serializable` — JSON model `fromJson`/`toJson` (`.g.dart`)
- `hive_generator` — Hive type adapters (`.g.dart`)
- `mockito` — Test mocks (`.mocks.dart`)

Run after changing annotated classes: `dart run build_runner build --delete-conflicting-outputs`
