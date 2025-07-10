# Saved Guides Module Summary

This document provides a comprehensive overview of the "Saved Guides" module in the Disciplefy Bible Study app's frontend. This module is responsible for managing and displaying study guides that users have either explicitly saved or recently accessed. It demonstrates a transition from a local-only storage solution to an API-driven approach, while maintaining a Clean Architecture structure.

## 1. Architecture Overview

The module adheres to a Clean Architecture pattern, separating concerns into distinct layers:

-   **Data Layer (`data/`)**: Handles data sources (local and remote), models for data transfer, and repositories for abstracting data access.
-   **Domain Layer (`domain/`)**: Contains core business entities, use cases (interactors), and abstract repository interfaces. This layer is independent of any specific data storage or UI framework.
-   **Presentation Layer (`presentation/`)**: Manages the UI, state management (using BLoC), and user interactions.

## 2. Key Components

### 2.1. Domain Layer

-   **`SavedGuideEntity` (`domain/entities/saved_guide_entity.dart`)**:
    -   The core immutable entity representing a study guide.
    -   Includes properties like `id`, `title`, `content`, `type` (verse/topic), `createdAt`, `lastAccessedAt`, `isSaved`, `verseReference`, and `topicName`.
    -   Provides helper getters like `displayTitle` and `subtitle` for UI presentation.
-   **`SavedGuidesRepository` (`domain/repositories/saved_guides_repository.dart`)**:
    -   An abstract interface defining the contract for data operations related to saved and recent guides (e.g., `getSavedGuides`, `saveGuide`, `removeGuide`, `watchSavedGuides`).
    -   This abstraction allows the domain layer to remain unaware of the underlying data storage mechanism.
-   **Use Cases (`domain/usecases/`)**:
    -   Each use case represents a specific business operation. They orchestrate interactions between the presentation layer and the repository.
    -   Examples: `GetSavedGuides`, `GetRecentGuides`, `SaveGuide`, `RemoveGuide`, `AddToRecent`.

### 2.2. Data Layer

-   **`SavedGuideModel` (`data/models/saved_guide_model.dart`)**:
    -   A data model that extends `SavedGuideEntity`.
    -   Used for serialization/deserialization from JSON (for API) and to/from Hive (local storage).
    -   Includes `HiveType` annotations for Hive persistence and `JsonSerializable` annotations for JSON conversion.
    -   `fromApiResponse` factory method handles parsing complex API response structures into a flat `SavedGuideModel`.
-   **`SavedGuidesLocalDataSource` (`data/datasources/saved_guides_local_data_source.dart`)**:
    -   Abstract interface for local data operations.
    -   `SavedGuidesLocalDataSourceImpl`: Concrete implementation using `Hive` (a local NoSQL database) for storing and retrieving `SavedGuideModel`s.
    -   Manages two Hive boxes: `saved_guides` and `recent_guides`.
    -   Provides `Stream`s (`watchSavedGuides`, `watchRecentGuides`) for real-time updates to the UI.
    -   Implements logic for limiting the number of recent guides.
-   **`StudyGuidesApiService` (`data/services/study_guides_api_service.dart`)**:
    -   Handles direct HTTP communication with the backend API's `/functions/v1/study-guides` endpoint.
    -   Fetches saved/recent guides and provides functionality to `saveUnsaveGuide` (toggle `is_saved` status on the backend).
    -   Uses `flutter_secure_storage` to retrieve authentication tokens for API requests.
    -   Includes robust error handling for network, server, and authentication exceptions.
-   **`UnifiedStudyGuidesService` (`data/services/unified_study_guides_service.dart`)**:
    -   A service that acts as a facade, deciding whether to fetch data from the API based on the user's authentication status.
    -   If the user is authenticated, it delegates to `StudyGuidesApiService`.
    -   If the user is a guest or not fully authenticated, it returns a `StudyGuidesResult.authRequired()` to prompt login.
    -   Wraps API responses in a `StudyGuidesResult` class to clearly indicate success, error, or authentication requirements.
-   **`SavedGuidesRepositoryImpl` (`data/repositories/saved_guides_repository_impl.dart`)**:
    -   Concrete implementation of `SavedGuidesRepository`.
    -   Currently, it primarily delegates to `SavedGuidesLocalDataSource`. This suggests that the API integration is handled at a higher level (BLoC) or that the local storage is still the primary source for saved/recent guides, with the API being used for syncing or for a separate "API-driven" view.

### 2.3. Presentation Layer

-   **`SavedGuidesBloc` (`presentation/bloc/saved_guides_bloc.dart`)**:
    -   Manages the state for the local-storage-based saved guides view.
    -   Uses use cases (`GetSavedGuides`, `GetRecentGuides`, `SaveGuide`, `RemoveGuide`, `AddToRecent`) to interact with the repository.
    -   Listens to `watchSavedGuides` and `watchRecentGuides` streams from the repository to update its state in real-time.
    -   Emits `SavedGuidesState`s (Initial, Loading, Loaded, Error, ActionSuccess).
-   **`SavedGuidesApiBloc` (`presentation/bloc/saved_guides_api_bloc.dart`)**:
    -   An *enhanced* BLoC specifically designed for the API-driven view of study guides.
    -   Directly interacts with `UnifiedStudyGuidesService` to fetch and manage guides from the backend.
    -   Implements pagination logic (`_savedOffset`, `_recentOffset`, `_pageSize`) and scroll listeners for "load more" functionality.
    -   Handles tab changes (`TabChangedEvent`) to load data for the active tab.
    -   Manages loading states (`isLoadingSaved`, `isLoadingRecent`) and `hasMore` flags for infinite scrolling.
    -   Emits `SavedGuidesApiLoaded` state, which includes separate lists for saved and recent guides, along with loading and pagination indicators.
    -   Handles `SavedGuidesAuthRequired` state to prompt users to sign in.
-   **`SavedGuidesEvent` (`presentation/bloc/saved_guides_event.dart`)**:
    -   Defines events for both local (`LoadSavedGuides`, `SaveGuideEvent`) and API-driven (`LoadSavedGuidesFromApi`, `ToggleGuideApiEvent`) operations.
-   **`SavedGuidesState` (`presentation/bloc/saved_guides_state.dart`)**:
    -   Defines states for both local (`SavedGuidesLoaded`) and API-driven (`SavedGuidesApiLoaded`) views.
    -   `SavedGuidesApiLoaded` is more comprehensive, including pagination and loading indicators.
-   **`SavedScreen` (`presentation/pages/saved_screen.dart`)**:
    -   The UI for the local-storage-based saved guides.
    -   Uses `TabController` to switch between "Saved" and "Recent" tabs.
    -   Displays guides using `GuideListItem`.
    -   Handles refresh actions and shows empty states.
-   **`SavedScreenApi` (`presentation/pages/saved_screen_api.dart`)**:
    -   The UI for the API-driven saved guides.
    -   Similar to `SavedScreen` but uses `SavedGuidesApiBloc` and `GuideListItemApi`.
    -   Implements scroll listeners for infinite scrolling.
    -   Displays loading indicators (shimmer effects or circular progress) and error states.
-   **Widgets (`presentation/widgets/`)**:
    -   **`GuideListItem`**: Displays a single study guide item for the local view, with options to remove.
    -   **`GuideListItemApi`**: Displays a single study guide item for the API view, with options to save/unsave and a loading overlay.
    -   **`EmptyStateWidget`**: Reusable widget for displaying empty states.
    -   **`GuideShimmerItem`**: Placeholder for loading states, providing a shimmering effect.

## 3. Data Flows and Interactions

The module supports two primary modes of operation for managing study guides:

### 3.1. Local Storage Flow (via `SavedGuidesBloc` and `SavedScreen`)

1.  **Initialization**: `SavedScreen` dispatches `LoadSavedGuides`, `WatchSavedGuidesEvent`, and `WatchRecentGuidesEvent` to `SavedGuidesBloc`.
2.  **Data Retrieval**: `SavedGuidesBloc` uses `GetSavedGuides` and `GetRecentGuides` use cases, which in turn call `SavedGuidesRepositoryImpl`, delegating to `SavedGuidesLocalDataSourceImpl` to fetch data from Hive.
3.  **Real-time Updates**: `SavedGuidesLocalDataSourceImpl` provides `Stream`s, allowing `SavedGuidesBloc` to automatically update the UI whenever guides are added, removed, or modified locally.
4.  **User Actions**:
    -   **Save/Remove**: `SaveGuideEvent` and `RemoveGuideEvent` trigger corresponding use cases, which update Hive via the repository and data source.
    -   **Add to Recent**: `AddToRecentEvent` updates the recent guides in Hive.
    -   **Open Guide**: Navigates to `/study-guide` and also adds the opened guide to recent.

### 3.2. API-Driven Flow (via `SavedGuidesApiBloc` and `SavedScreenApi`)

1.  **Initialization**: `SavedScreenApi` dispatches `LoadSavedGuidesFromApi` (for saved guides) and `TabChangedEvent` (to load recent guides when the tab is switched) to `SavedGuidesApiBloc`.
2.  **Authentication Check**: `SavedGuidesApiBloc` uses `UnifiedStudyGuidesService` to check if the user is authenticated. If not, it emits `SavedGuidesAuthRequired` state, prompting the user to sign in.
3.  **Data Retrieval (API)**: If authenticated, `UnifiedStudyGuidesService` calls `StudyGuidesApiService` to fetch guides from the backend.
    -   Pagination is handled by passing `limit` and `offset` parameters.
4.  **State Updates**: `SavedGuidesApiBloc` processes the API response, updates its internal lists of `savedGuides` and `recentGuides`, and emits `SavedGuidesApiLoaded` state.
5.  **Infinite Scrolling**: `SavedScreenApi` uses `ScrollController`s to detect when the user scrolls near the end of the list and triggers `LoadSavedGuidesFromApi` or `LoadRecentGuidesFromApi` with updated `offset` to fetch more data.
6.  **User Actions**:
    -   **Save/Unsave**: `ToggleGuideApiEvent` is dispatched, which calls `UnifiedStudyGuidesService.toggleSaveGuide`. This updates the `is_saved` status on the backend. The UI is then updated to reflect the change.
    -   **Open Guide**: Navigates to `/study-guide`.

## 4. Key Design Principles

-   **Clean Architecture**: Clear separation of concerns, making the module testable and maintainable.
-   **BLoC Pattern**: Effective state management for complex UI interactions and asynchronous data operations.
-   **Repository Pattern**: Abstracts data access, allowing the application to switch between local and remote data sources without affecting business logic.
-   **`dartz` for Functional Error Handling**: Uses `Either` to explicitly represent success or failure outcomes, improving type safety and error propagation.
-   **Local Persistence (`Hive`)**: Provides fast and efficient local storage for offline access and caching.
-   **API Integration**: Seamlessly integrates with a backend API for synchronized data and user-specific content.
-   **User Experience**: Includes loading indicators (shimmer), empty states, and pagination for a smooth user experience.

## 5. Potential Improvements/Considerations

-   **Data Synchronization Strategy**: The current setup has two distinct flows (local and API). A robust synchronization strategy would be crucial to ensure data consistency between local storage and the backend, especially for offline capabilities and multi-device usage. This might involve:
    -   **Offline-first approach**: Always read from local, sync with API in background.
    -   **Conflict Resolution**: How to handle conflicts if a guide is modified locally and on the server.
-   **Unified Repository**: Instead of `SavedGuidesRepositoryImpl` only using local data source, it could be extended to coordinate between local and remote data sources (e.g., fetch from API, then cache locally; or update local, then sync to API). This would centralize data access logic.
-   **Error Handling Refinement**: While errors are handled, more granular error types and user-friendly messages could be implemented, especially for API-related failures.
-   **Performance Optimization**: For very large lists of guides, further optimizations like virtualized lists or more aggressive caching might be considered.
-   **Guest User Experience**: Currently, guest users are prompted to sign in to view saved/recent guides from the API. A clearer explanation of why this is necessary and what benefits they gain by signing in could improve the user journey.
-   **Code Duplication**: Some UI logic (e.g., `_buildLoadingIndicator`, `_buildErrorState`) is duplicated between `SavedScreen` and `SavedScreenApi`. These could be extracted into reusable widgets.

This summary provides a comprehensive understanding of the Saved Guides module's design and functionality, highlighting its current capabilities and areas for future enhancement.
