# Frontend Feedback Module: Code Review and Analysis

**Date**: July 20, 2025

This document provides a detailed analysis of the Feedback module. Since the feedback UI is currently initiated from the `SettingsScreen`, this review considers the interaction between the `settings` and `feedback` features.

---

## 1. Critical Issues & Logical Errors

### 1.1. UI Layer Directly Calling Data Service (Critical Architecture Violation)

-   **Issue**: The `_submitFeedback` method within `SettingsScreen` directly instantiates and calls the `FeedbackService`. This completely bypasses the BLoC and domain layers (use cases, repositories), which is a major violation of the project's Clean Architecture principles.
-   **Location**: `frontend/lib/features/settings/presentation/pages/settings_screen.dart`
-   **Consequences**:
    -   **Untestable UI**: The `SettingsScreen` is tightly coupled to the `FeedbackService`, making it difficult to write unit tests for the feedback submission logic without a full implementation of the service.
    -   **No Centralized State Management**: The loading and error states for feedback submission are handled with local `try-catch` blocks and `_showSnackBar` calls within the widget. This logic should be managed by a BLoC to ensure a predictable and consistent state.
    -   **Poor Separation of Concerns**: The UI is responsible for business logic (calling the service, handling errors), which it should not be.
-   **Recommendation**:
    1.  **Create a `FeedbackBloc`**. This BLoC will manage the state of feedback submission (`FeedbackInitial`, `FeedbackSubmitting`, `FeedbackSuccess`, `FeedbackFailure`).
    2.  **Create a `SubmitFeedbackUseCase`** in the domain layer that the `FeedbackBloc` will call.
    3.  **Create a `FeedbackRepository`** that the use case will depend on. This repository will abstract the data source.
    4.  Refactor `FeedbackService` to be a `FeedbackRemoteDataSource` that is called by the `FeedbackRepository`.
    5.  The `SettingsScreen` should then dispatch a `SubmitFeedbackRequested` event to the `FeedbackBloc` and react to the resulting states to show loading indicators or success/error messages.

---

## 2. SOLID Principles Violations

### 2.1. Single Responsibility Principle (SRP)

-   **Violation**: The `SettingsScreen` widget is responsible for displaying all application settings *and* for handling the entire UI and business logic for two different feedback flows ("Send Feedback" and "Report Issue").
-   **Location**: `frontend/lib/features/settings/presentation/pages/settings_screen.dart`
-   **Suggestion**: The feedback submission functionality should be extracted into its own dedicated widgets or even its own page. The `SettingsScreen` should only be responsible for providing the entry point (e.g., a button that navigates to a feedback screen or shows a dedicated feedback dialog widget).

-   **Violation**: The `FeedbackService` is responsible for constructing the `user_context` object. This mixes the concern of data submission with the concern of user session management.
-   **Location**: `frontend/lib/features/feedback/data/services/feedback_service.dart`
-   **Suggestion**: The `user_context` should be passed into the `submitFeedback` method from the business logic layer (e.g., the BLoC), which would get the current user state from the `AuthBloc`. This makes the `FeedbackService` simpler and more focused on its primary task of sending data.

---

## 3. Clean Code & Other Suggestions

-   **Inconsistent Error Handling**:
    -   **Issue**: The `submitFeedback` method in `FeedbackService` catches all exceptions and re-throws a generic `Exception`. This is inconsistent with the `AppException` and `Failure` hierarchy used in other modules.
    -   **Location**: `frontend/lib/features/feedback/data/services/feedback_service.dart`
    -   **Suggestion**: The service should throw specific `AppException` types (e.g., `ServerException`, `NetworkException`). The repository would then catch these and return corresponding `Failure` types (e.g., `ServerFailure`) for the BLoC to handle.

-   **Direct Dependency on `SupabaseClient`**:
    -   **Issue**: The `FeedbackService` directly uses `Supabase.instance.client`. While this works, it makes the service harder to test in isolation.
    -   **Suggestion**: The `SupabaseClient` instance should be passed into the `FeedbackService`'s constructor via dependency injection (GetIt), just like the `HttpService` is handled in other services.
