# Daily Verse Module Summary

This document provides a comprehensive overview of the "Daily Verse" module in the Disciplefy Bible Study app's frontend. This module is responsible for fetching, caching, and displaying a daily Bible verse, along with managing user preferences for verse language. It adheres to a Clean Architecture pattern for maintainability and testability.

## 1. Architecture Overview

The module is structured according to Clean Architecture principles, dividing responsibilities into distinct layers:

-   **Domain Layer (`domain/`)**: Defines the core business logic, entities, and abstract contracts (repositories, use cases) independent of any specific implementation details.
-   **Data Layer (`data/`)**: Implements the contracts defined in the domain layer, handling data sources (API and local cache), and data models.
-   **Presentation Layer (`presentation/`)**: Manages the user interface and state management using the BLoC pattern.

## 2. Key Components

### 2.1. Domain Layer

-   **`DailyVerseEntity` (`domain/entities/daily_verse_entity.dart`)**:
    -   The core immutable entity representing a daily Bible verse.
    -   Includes `reference` (e.g., "John 3:16"), `translations` (a `DailyVerseTranslations` object), and `date`.
    -   Provides helper getters for `getVerseText` (based on preferred language), `isToday`, and `formattedDate`.
-   **`DailyVerseTranslations` (`domain/entities/daily_verse_entity.dart`)**:
    -   An immutable class holding the verse text in different languages (ESV, Hindi, Malayalam).
-   **`VerseLanguage` (`domain/entities/daily_verse_entity.dart`)**:
    -   An enum representing the supported languages for the daily verse (English, Hindi, Malayalam). Includes extensions for `code`, `displayName`, and `flag`.
-   **`DailyVerseRepository` (`domain/repositories/daily_verse_repository.dart`)**:
    -   An abstract interface defining the contract for daily verse data operations (e.g., `getTodaysVerse`, `getDailyVerse`, `getCachedVerse`, `cacheVerse`, `getPreferredLanguage`, `setPreferredLanguage`, `isServiceAvailable`, `getCacheStats`, `clearCache`).
-   **Use Cases (`domain/usecases/`)**:
    -   **`GetDailyVerse`**: Fetches the daily verse for today or a specific date.
    -   **`GetPreferredLanguage`**: Retrieves the user's preferred verse language.
    -   **`SetPreferredLanguage`**: Persists the user's preferred verse language.
    -   **`GetCacheStats`**: Retrieves statistics about the daily verse cache.
    -   **`ClearVerseCache`**: Clears all cached daily verses.

### 2.2. Data Layer

-   **Models (`data/models/daily_verse_model.dart`)**:
    -   **`DailyVerseModel`**: Data model for the daily verse API response, including `reference`, `translations` (a `DailyVerseTranslationsModel`), and `date`.
    -   **`DailyVerseTranslationsModel`**: Data model for verse translations.
    -   **`DailyVerseResponse`**: Wraps the `DailyVerseModel` with a `success` flag.
    -   These models include `fromJson` and `toJson` methods for JSON serialization/deserialization and `toEntity` methods for conversion to domain entities.
-   **Services (`data/services/`)**:
    -   **`DailyVerseApiService`**: Handles direct HTTP communication with the backend API's `/functions/v1/daily-verse` endpoint.
        -   Fetches daily verses for today or a specific date.
        -   Uses `flutter_secure_storage` to retrieve authentication tokens for API requests.
        -   Includes robust error handling for network, server, and authentication exceptions.
        -   Provides an `isServiceAvailable` health check.
    -   **`DailyVerseCacheService`**: Manages local caching of daily verses.
        -   Uses `Hive` (a local NoSQL database) for structured verse data and `SharedPreferences` for simple settings like `last_fetch_time` and `preferred_verse_language`.
        -   Implements `cacheVerse`, `getCachedVerse`, `getPreferredLanguage`, `setPreferredLanguage`, `shouldRefresh` (based on a 1-hour interval), `getCacheStats`, and `clearCache`.
        -   Includes logic to clean up old cache entries (older than 30 days).
-   **`DailyVerseRepositoryImpl` (`data/repositories/daily_verse_repository_impl.dart`)**:
    -   Concrete implementation of `DailyVerseRepository`.
    -   Acts as a coordinator between `DailyVerseApiService` and `DailyVerseCacheService`.
    -   **Caching Strategy**:
        -   First, checks if a refresh is needed (`shouldRefresh`). If not, it tries to retrieve the verse from the cache.
        -   If a refresh is needed or the verse is not in cache, it attempts to fetch from the API.
        -   If API succeeds, it caches the new verse.
        -   If API fails, it falls back to `DailyVerseCacheService.getCachedVerse()` as a last resort.
    -   Uses `dartz`'s `Either` for functional error handling.

### 2.3. Presentation Layer

-   **BLoC (`presentation/bloc/`)**:
    -   **`DailyVerseBloc`**: Manages the state of the daily verse display.
    -   **Events (`DailyVerseEvent`)**:
        -   `LoadTodaysVerse`: Loads today's verse (can force refresh).
        -   `LoadVerseForDate`: Loads a verse for a specific date.
        -   `ChangeVerseLanguage`: Changes the displayed language (temporary, not persisted).
        -   `SetPreferredVerseLanguage`: Changes and persists the preferred verse language.
        -   `RefreshVerse`: Forces a refresh of the current verse.
        -   `LoadCachedVerse`: Attempts to load only from cache.
        -   `GetCacheStatsEvent`: Requests cache statistics.
        -   `ClearVerseCacheEvent`: Requests to clear the cache.
    -   **States (`DailyVerseState`)**:
        -   `DailyVerseInitial`: Initial state.
        -   `DailyVerseLoading`: Verse is being loaded.
        -   `DailyVerseLoaded`: Verse successfully loaded, includes `DailyVerseEntity`, `currentLanguage`, `preferredLanguage`, `isFromCache`, `isServiceAvailable`.
        -   `DailyVerseError`: An error occurred during loading.
        -   `DailyVerseOffline`: Displays a cached verse when offline.
        -   `DailyVerseCacheStats`: Displays cache statistics.
        -   `DailyVerseCacheCleared`: Indicates cache cleared successfully.
        -   `DailyVerseLanguageUpdated`: Indicates language preference updated.
    -   **Logic**: Handles incoming events by calling the appropriate use cases and updating the state. It coordinates fetching from API and cache based on network status and caching logic.
-   **Widgets (`presentation/widgets/`)**:
    -   **`DailyVerseCard`**: A reusable UI widget for displaying the daily verse on the home screen.
        -   Displays the verse reference, text in the selected language, and date.
        -   Provides language tabs for switching between translations.
        -   Includes action buttons for copying, sharing, and refreshing the verse.
        -   Handles different states (loading, loaded, error, offline) with appropriate UI feedback (shimmer, error messages, retry buttons).

## 3. Data Flows and Interactions

1.  **Initial Load (`LoadTodaysVerse`)**:
    -   `DailyVerseBloc` receives `LoadTodaysVerse`.
    -   It first retrieves the user's `preferredLanguage` from `DailyVerseRepositoryImpl`.
    -   Then, it calls `DailyVerseRepositoryImpl.getTodaysVerse()`.
    -   `DailyVerseRepositoryImpl` checks `DailyVerseCacheService.shouldRefresh()`.
        -   If `false` (cache is fresh), it tries `DailyVerseCacheService.getCachedVerse()`. If found, it returns the cached verse.
        -   If `true` (cache is stale) or no cached verse, it attempts to fetch from the API.
            -   If API succeeds, `DailyVerseRepositoryImpl` caches the verse and returns it.
            -   If API fails, it falls back to `DailyVerseCacheService.getCachedVerse()` as a last resort.
    -   `DailyVerseBloc` receives the `Either` result and emits `DailyVerseLoaded` or `DailyVerseError` (or `DailyVerseOffline` if a cached fallback was used).
    -   `DailyVerseCard` updates its UI based on the emitted state.
2.  **Language Change (`ChangeVerseLanguage`)**:
    -   User taps a language tab on `DailyVerseCard`.
    -   `DailyVerseCard` dispatches `ChangeVerseLanguage` to `DailyVerseBloc`.
    -   `DailyVerseBloc` updates the `currentLanguage` in its `DailyVerseLoaded` or `DailyVerseOffline` state and re-emits, causing the UI to display the verse in the new language without refetching.
3.  **Set Preferred Language (`SetPreferredVerseLanguage`)**:
    -   User explicitly sets a preferred language (e.g., in settings).
    -   `SetPreferredVerseLanguage` is dispatched.
    -   `DailyVerseBloc` calls `DailyVerseRepositoryImpl.setPreferredLanguage()`, which uses `DailyVerseCacheService` to persist the choice.
    -   The BLoC then updates its state to reflect the new `preferredLanguage`.
4.  **Refresh (`RefreshVerse`)**:
    -   User taps the refresh button.
    -   `RefreshVerse` is dispatched, which internally triggers `LoadTodaysVerse(forceRefresh: true)`. This bypasses the `shouldRefresh` check and forces an API call.

## 4. Key Design Principles

-   **Clean Architecture**: Clear separation of concerns, making the module modular, testable, and scalable.
-   **BLoC Pattern**: Provides a predictable and manageable way to handle UI state and business logic, especially for asynchronous operations like API calls and caching.
-   **Repository Pattern**: Abstracts data access, allowing for flexible data sources (API and local cache) and a robust caching strategy.
-   **Use Cases**: Encapsulate specific business rules, making the code more readable and maintainable.
-   **Local Caching (`Hive`, `SharedPreferences`)**: Improves user experience by providing offline access to daily verses and reducing reliance on constant network calls.
-   **Offline-First Strategy**: Prioritizes serving cached data when available and fresh, falling back to it when the network is unavailable.
-   **Robust Error Handling**: Comprehensive error handling at each layer, with user-friendly messages and retry mechanisms.

## 5. Potential Improvements/Considerations

-   **Background Fetching**: Implement background fetching for the daily verse to ensure it's always fresh when the app is opened, even if the user hasn't opened it for a while. This would involve platform-specific background tasks.
-   **Notification Integration**: Integrate with the app's notification system to send daily verse reminders, leveraging the `dailyVerseReminder` setting from the Settings module.
-   **More Granular Error States**: While `DailyVerseError` is generic, more specific error types could be defined (e.g., `DailyVerseNetworkError`, `DailyVerseServerError`) to allow for more tailored UI responses.
-   **Internationalization of Verse Content**: The current implementation assumes the backend provides translations. If not, a translation service could be integrated on the frontend.
-   **Testing**: Ensure comprehensive unit and integration tests for all layers, especially the caching logic and API interactions.

This summary provides a comprehensive understanding of the Daily Verse module's design and functionality, highlighting its current capabilities and areas for future enhancement.