# Home Module Summary

This document provides an overview of the home module within the Disciplefy Bible Study app's frontend, focusing on its architecture, key components, and data flows.

## 1. Architecture Overview

The home module follows a Clean Architecture-inspired structure, similar to other feature modules, separating concerns into:

-   **Data Layer (`data/`)**: Handles data models for API responses and services for fetching data from the backend.
-   **Domain Layer (`domain/`)**: Contains core business entities, such as `RecommendedGuideTopic`.
-   **Presentation Layer (`presentation/`)**: Manages the UI (`HomeScreen`) and displays data, interacting with services to fetch necessary information.

## 2. Key Components

### 2.1. `RecommendedGuideTopic` (`domain/entities/recommended_guide_topic.dart`)

This is the core domain entity representing a recommended study guide topic. It's an immutable data class extending `Equatable` for value comparison.

**Key Attributes:**

-   `id`: Unique identifier for the topic.
-   `title`, `description`, `category`: Basic information about the topic.
-   `difficulty`: Level of difficulty (e.g., "beginner", "intermediate").
-   `estimatedMinutes`: Estimated study duration.
-   `scriptureCount`: Number of related scripture passages.
-   `tags`: Keywords associated with the topic.
-   `isFeatured`: Flag indicating if the topic is featured.
-   `createdAt`: Timestamp of creation.

### 2.2. `RecommendedGuideTopicModel` (`data/models/recommended_guide_topic_model.dart`)

This model extends `RecommendedGuideTopic` and is used for serialization and deserialization of API responses using `json_annotation`. It includes specific JSON keys (`difficulty_level`, `estimated_duration`, `key_verses`) that map to the backend API's naming conventions and handles parsing of `estimatedDuration` string into integer minutes.

### 2.3. `RecommendedGuideTopicsResponse` (`data/models/recommended_guide_topic_model.dart`)

This class represents the overall structure of the API response for recommended topics, containing a list of `RecommendedGuideTopicModel`s, total count, and pagination details.

### 2.4. `RecommendedGuideTopicsApiResponse` (`data/models/recommended_guide_topic_response.dart`)

This is another response model that wraps the `RecommendedGuideTopicsData` and a `success` flag. It's used by the `RecommendedGuidesService` to parse the top-level API response.

### 2.5. `RecommendedGuidesService` (`data/services/recommended_guides_service.dart`)

This service is responsible for making HTTP requests to the backend API to fetch recommended study guide topics. It uses `dartz` for functional error handling (`Either` type) and `flutter_secure_storage` for retrieving authentication tokens.

**Key Responsibilities:**

-   **API Calls**: Fetches all topics or filtered topics based on category, difficulty, and limit from the `/functions/v1/topics-recommended` endpoint.
-   **Authentication**: Attaches `Authorization` headers using a bearer token retrieved from secure storage or the Supabase anonymous key.
-   **Error Handling**: Catches network errors, HTTP status code errors (e.g., 401 Unauthorized), and JSON parsing errors, returning appropriate `Failure` types.
-   **Response Parsing**: Parses the JSON response into `RecommendedGuideTopic` entities.

### 2.6. `HomeScreen` (`presentation/pages/home_screen.dart`)

This is the main UI screen for the home module. It displays a welcome message, daily verse, a button to generate study guides, and a grid of recommended study topics.

**Key Responsibilities:**

-   **UI Layout**: Arranges various widgets like app header, welcome message, daily verse card, and recommended topics grid.
-   **Data Loading**:
    -   Loads user data (`_currentUserName`, `_userType`) from `FlutterSecureStorage`.
    -   Loads recommended topics using `RecommendedGuidesService`.
    -   Dispatches `LoadTodaysVerse` event to `DailyVerseBloc` to fetch the daily verse.
-   **State Management**: Manages local UI state for loading indicators, error messages, and the list of recommended topics.
-   **Navigation**: Handles navigation to other screens like `/settings` and `/generate-study`.
-   **Error and Loading States**: Displays appropriate UI (loading skeletons, error messages, retry buttons) based on the status of data fetching.
-   **`_RecommendedGuideTopicCard`**: A private widget within `HomeScreen` that displays individual recommended topic cards, including icons based on category and colors based on difficulty.

## 3. Data Flows

1.  **Initialization**:
    -   When `HomeScreen` initializes, it calls `_initializeScreen()`.
    -   `_loadUserData()` retrieves user type and name from `FlutterSecureStorage`.
    -   `_loadRecommendedTopics()` initiates an API call via `RecommendedGuidesService.getFilteredTopics()` to fetch recommended topics.
    -   `_loadDailyVerse()` dispatches an event to the `DailyVerseBloc` to fetch the daily verse.
2.  **Recommended Topics Fetching**:
    -   `RecommendedGuidesService` makes an HTTP GET request to the backend.
    -   It includes `Content-Type`, `apikey`, and `Authorization` headers.
    -   Upon receiving a 200 OK response, it parses the JSON into `RecommendedGuideTopicsApiResponse` and then converts the `RecommendedGuideTopicModel`s into `RecommendedGuideTopic` entities.
    -   The result (either a list of topics or a `Failure`) is folded, and the `HomeScreen`'s state is updated to display the topics or an error message.
3.  **User Interaction**:
    -   Tapping "Generate Study Guide" navigates to `/generate-study`.
    -   Tapping a recommended topic card navigates to `/generate-study` with the topic's details passed as `extra` parameters, allowing the study guide generation screen to pre-fill based on the selected topic.

## 4. Error Handling

-   **`RecommendedGuidesService`**: Implements robust error handling for network issues, unauthorized access (401), and other server errors, returning `Failure` objects.
-   **`HomeScreen`**: Checks the `Either` result from `RecommendedGuidesService`. If a `Failure` is returned, it updates `_topicsError` and displays an error message with a retry button. It also handles cases where no topics are available.

## 5. Potential Improvements/Considerations

-   **BLoC for Home Screen State**: While `DailyVerseBloc` is used for the daily verse, the `HomeScreen` itself manages its state (user name, topics, loading, error) using `setState`. For more complex interactions or shared state, introducing a `HomeBloc` could further align with the BLoC pattern used elsewhere.
-   **Pagination/Load More**: The `RecommendedGuidesService` has `page` and `totalPages` in its response models, suggesting pagination capabilities. The `HomeScreen` currently fetches a limited number of topics (`limit: 6`). Implementing "load more" functionality or infinite scrolling would enhance user experience for a larger set of topics.
-   **User Profile Integration**: The user's name is loaded from secure storage. If the user's display name is part of their profile (as seen in `AuthBloc`), it might be more consistent to retrieve it from the `AuthBloc`'s state.
-   **Offline Support**: Consider implementing caching mechanisms for recommended topics to provide a better experience when offline.
-   **Dynamic Icons/Colors**: While the current implementation uses a `switch` statement for icons and colors based on category/difficulty, a more scalable solution might involve mapping these in a configuration file or fetching them from the backend if they become more dynamic.

This summary provides a comprehensive understanding of the home module's design and functionality.
