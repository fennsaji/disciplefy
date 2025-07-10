# Study Generation Module Summary

This document provides a comprehensive overview of the "Study Generation" module in the Disciplefy Bible Study app's frontend. This module is responsible for allowing users to generate personalized Bible study guides based on scripture references or topics, and then displaying these generated guides. It adheres to a Clean Architecture pattern for maintainability and testability.

## 1. Architecture Overview

The module is structured according to Clean Architecture principles, dividing responsibilities into distinct layers:

-   **Domain Layer (`domain/`)**: Defines the core business logic, entities, and abstract contracts (repositories, use cases) independent of any specific implementation details.
-   **Data Layer (`data/`)**: Implements the contracts defined in the domain layer, handling data storage (local cache) and communication with the backend API.
-   **Presentation Layer (`presentation/`)**: Manages the user interface and state management using the BLoC pattern.

## 2. Key Components

### 2.1. Domain Layer

-   **`StudyGuide` (`domain/entities/study_guide.dart`)**:
    -   The core immutable entity representing a generated Bible study guide.
    -   Includes properties like `id`, `input` (the original verse/topic), `inputType`, `summary`, `interpretation`, `context`, `relatedVerses`, `reflectionQuestions`, `prayerPoints`, `language`, `createdAt`, and an optional `userId`.
    -   Provides helper getters like `title` (derived from input), `isComplete`, and `estimatedReadingTimeMinutes`.
-   **`StudyRepository` (`domain/repositories/study_repository.dart`)**:
    -   An abstract interface defining the contract for study guide data operations (e.g., `generateStudyGuide`, `getCachedStudyGuides`, `cacheStudyGuide`, `clearCache`).
-   **`GenerateStudyGuide` (`domain/usecases/generate_study_guide.dart`)**:
    -   A use case that encapsulates the business logic for generating a study guide.
    -   Takes `StudyGenerationParams` (input, input type, language) as input.
    -   Performs input validation (e.g., empty input, length limits, valid input type).
    -   Calls the `StudyRepository` to perform the actual generation.

### 2.2. Data Layer

-   **`StudyRepositoryImpl` (`data/repositories/study_repository_impl.dart`)**:
    -   Concrete implementation of `StudyRepository`.
    -   **Study Guide Generation**: Interacts with the Supabase Edge Function (`study-generate`) to generate study guides.
        -   Handles network connectivity checks.
        -   Prepares user context (authenticated user ID or anonymous session ID) and authentication tokens for the API request.
        -   Parses the API response into a `StudyGuide` entity.
        -   Handles various API response statuses (success, rate limit, server errors).
    -   **Local Caching**: Uses `Hive` (a local NoSQL database) to cache generated study guides.
        -   `cacheStudyGuide`: Stores a `StudyGuide` in a Hive box (`study_guides`).
        -   `getCachedStudyGuides`: Retrieves cached guides, sorts them by creation date, and limits the number of returned guides (`MAX_STUDY_GUIDES_CACHE`).
        -   `clearCache`: Clears all cached study guides.
    -   **Authentication/Session Management**: Integrates with `AuthService` to get authentication tokens and user IDs, and generates/manages anonymous session IDs using Hive.
-   **`SaveGuideApiService` (`data/services/save_guide_api_service.dart`)**:
    -   A separate API service specifically for saving/unsaving study guides on the backend.
    -   Communicates with the `/functions/v1/study-guides` endpoint.
    -   Handles authentication headers and various API response statuses (unauthorized, not found, server errors).

### 2.3. Presentation Layer

-   **BLoC (`presentation/bloc/`)**:
    -   **`StudyBloc`**: Manages the state of the study guide generation process.
    -   **Events (`StudyEvent`)**:
        -   `GenerateStudyGuideRequested`: Triggered when the user requests a study guide.
        -   `StudyGuideCleared`: Resets the BLoC state.
    -   **States (`StudyState`)**:
        -   `StudyInitial`: Initial state.
        -   `StudyGenerationInProgress`: Generation is ongoing, optionally with a progress indicator.
        -   `StudyGenerationSuccess`: Study guide successfully generated, holds the `StudyGuide` entity.
        -   `StudyGenerationFailure`: Generation failed, holds the `Failure` object and a `isRetryable` flag.
    -   **Logic**: Handles `GenerateStudyGuideRequested` by calling the `GenerateStudyGuide` use case. It maps the `Either` result from the use case to appropriate `StudyState`s. It also determines if a failure is retryable based on the `Failure` type.
-   **Pages (`presentation/pages/`)**:
    -   **`GenerateStudyScreen`**: The main screen where users input their study request.
        -   **Input Mode Toggle**: Allows switching between "Scripture Reference" and "Topic" input modes.
        -   **Input Field**: `TextField` for user input with basic validation and error display.
        -   **Suggestions**: Provides dynamic suggestions (scripture references or topics) that users can tap to pre-fill the input.
        -   **Generate Button**: Triggers `GenerateStudyGuideRequested` when valid input is provided.
        -   **Loading/Error UI**: Displays a loading indicator during generation and an error dialog on failure, with a "Try Again" option for retryable errors.
        -   **Navigation**: Navigates to `StudyGuideScreen` on successful generation.
    -   **`StudyGuideScreen`**: Displays the generated study guide content.
        -   **Content Sections**: Organizes the study guide into distinct sections (Summary, Interpretation, Context, Related Verses, Reflection Questions, Prayer Points) with icons and titles.
        -   **Personal Notes**: Provides a `TextField` for users to write personal notes.
        -   **Save Functionality**: Allows authenticated users to save the study guide to the backend via `SaveGuideApiService`. Handles loading states, success/error messages, and authentication requirements.
        -   **Share Functionality**: Allows users to share the study guide content via `Share.share`.
        -   **Error Handling**: Displays a dedicated error screen if no study guide data is provided or if an internal error occurs.
    -   **`StudyInputPage`**: (Appears to be an older or alternative input screen, as `GenerateStudyScreen` seems to be the primary one.) It uses `TabBar` for input mode selection and separate `VerseInputWidget` and `TopicInputWidget`. It also handles `StudyBloc` listening and error display.
    -   **`StudyResultPage`**: (Appears to be an older or alternative result screen, as `StudyGuideScreen` seems to be the primary one.) It displays the study guide content using `flutter_markdown` and provides share/new study buttons.
-   **Widgets (`presentation/widgets/`)**:
    -   **`VerseInputWidget`**: Reusable widget for scripture input, including format examples.
    -   **`TopicInputWidget`**: Reusable widget for topic input, including popular topic suggestions.

## 3. Data Flows and Interactions

1.  **User Initiates Generation**:
    -   On `GenerateStudyScreen`, the user selects an input mode (scripture/topic) and enters text.
    -   Upon tapping "Generate Study Guide", `GenerateStudyScreen` dispatches `GenerateStudyGuideRequested` to `StudyBloc`.
2.  **Study Guide Generation (BLoC & Repository)**:
    -   `StudyBloc` emits `StudyGenerationInProgress`.
    -   `StudyBloc` calls `GenerateStudyGuide` use case.
    -   `GenerateStudyGuide` validates the input. If invalid, it returns a `ValidationFailure`.
    -   If valid, `GenerateStudyGuide` calls `StudyRepositoryImpl.generateStudyGuide`.
    -   `StudyRepositoryImpl` checks network, gets user context/auth token, and invokes the Supabase Edge Function (`study-generate`).
    -   The backend generates the study guide content.
    -   `StudyRepositoryImpl` parses the backend response into a `StudyGuide` entity and caches it locally using Hive.
    -   The `StudyGuide` is returned up the chain.
3.  **Displaying Results**:
    -   `StudyBloc` receives the `StudyGuide` and emits `StudyGenerationSuccess`.
    -   `GenerateStudyScreen` listens to this state and navigates to `StudyGuideScreen`, passing the generated `StudyGuide` as an argument.
    -   `StudyGuideScreen` displays the content, allowing users to add notes, save, or share.
4.  **Saving Study Guide**:
    -   On `StudyGuideScreen`, if the user taps "Save Study", `_saveStudyGuide` is called.
    -   It first checks if the user is authenticated. If not, it prompts them to sign in.
    -   If authenticated, it calls `SaveGuideApiService.toggleSaveGuide` to update the `is_saved` status on the backend for the specific `StudyGuide.id`.
    -   The UI updates to reflect the saved status.
5.  **Error Handling**:
    -   Errors at any layer (validation, network, server, unexpected) are caught and propagated as `Failure` objects.
    -   `StudyBloc` maps these `Failure`s to `StudyGenerationFailure` states, which `GenerateStudyScreen` uses to display informative error dialogs, potentially with a retry option.

## 4. Key Design Principles

-   **Clean Architecture**: Clear separation of concerns, making the module modular, testable, and scalable.
-   **BLoC Pattern**: Provides a predictable and manageable way to handle UI state and business logic, especially for asynchronous operations like API calls.
-   **Repository Pattern**: Abstracts data access, allowing for flexible data sources (API and local cache).
-   **Use Cases**: Encapsulate specific business rules, making the code more readable and maintainable.
-   **Local Caching (`Hive`)**: Improves user experience by providing offline access to previously generated study guides and reducing reliance on constant network calls.
-   **Optimistic Updates**: (Implicit in `GenerateStudyScreen`'s loading state) Provides immediate feedback to the user.
-   **Robust Error Handling**: Comprehensive error handling at each layer, with user-friendly messages and retry mechanisms.

## 5. Potential Improvements/Considerations

-   **Unified Save/Unsave Logic**: The `SaveGuideApiService` is separate from `StudyRepositoryImpl`. While `StudyRepositoryImpl` handles generation and caching, the saving to the backend is a distinct service. Depending on the overall architecture, these could potentially be unified under a single `StudyRepository` that handles both local and remote persistence, or kept separate if their responsibilities are truly distinct.
-   **Offline Generation**: Currently, generation requires an internet connection. For a more robust offline experience, consider:
    -   **Queuing requests**: Store generation requests locally and process them when online.
    -   **Limited offline generation**: If a local LLM or pre-generated content is available.
-   **Progress Indicators**: The `StudyGenerationInProgress` state has a `progress` field, but it's not actively used to show a numerical progress. Implementing a more granular progress update from the backend or a simulated progress bar could enhance UX.
-   **User Feedback on Save**: While a SnackBar is shown, more prominent feedback for saving (e.g., a temporary checkmark animation on the save button) could be considered.
-   **Content Formatting**: The `StudyGuideScreen` directly displays the content. If the content from the API is Markdown, using `flutter_markdown` (as seen in `StudyResultPage`) would be more appropriate for rich text rendering.
-   **Redundant Pages**: `StudyInputPage` and `StudyResultPage` seem to be older versions of `GenerateStudyScreen` and `StudyGuideScreen` respectively. Consolidating these would simplify the codebase.

This summary provides a comprehensive understanding of the Study Generation module's design and functionality, highlighting its current capabilities and areas for future enhancement.
