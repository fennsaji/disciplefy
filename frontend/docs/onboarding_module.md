# Onboarding Module Summary

This document outlines the structure, flows, and implementation details of the onboarding module in the Disciplefy Bible Study app's frontend. The module is designed to guide new users through initial setup and introduce them to the app's core features.

## 1. Architecture Overview

The onboarding module primarily resides within the `presentation/pages` directory, indicating a UI-centric design. It does not strictly follow the Clean Architecture layers (data, domain, presentation) as it mainly focuses on user interface and local state management, with direct interactions with local storage (`Hive`) for preferences and navigation.

## 2. Key Components

### 2.1. `OnboardingScreen` (`presentation/pages/onboarding_screen.dart`)

This is the main entry point for the initial onboarding experience. It's a `StatefulWidget` that manages a `PageView` to display multiple onboarding slides.

**Key Responsibilities:**

-   **Carousel Navigation**: Uses `PageController` and `SmoothPageIndicator` to manage and display progress through three predefined onboarding slides.
-   **Slide Content**: Each slide (`_OnboardingSlideWidget`) presents a title, subtitle, description, an icon, and a relevant Bible verse, highlighting key app features (AI-powered guides, predefined topics, note-taking/progress tracking).
-   **Authentication Check**: On `initState`, it checks if the user is already authenticated via `AuthBloc`. If so, it redirects to the home screen, preventing authenticated users from re-entering onboarding.
-   **Navigation**: Provides "Skip" and "Continue/Get Started" buttons to navigate to the `OnboardingWelcomePage`.

### 2.2. `OnboardingWelcomePage` (`presentation/pages/onboarding_welcome_page.dart`)

This page serves as the final step of the initial onboarding flow, presenting authentication options (Google Login, Continue as Guest) and a summary of app features.

**Key Responsibilities:**

-   **App Introduction**: Displays the app logo, title, and a tagline.
-   **Feature Highlights**: Showcases key features (AI-Powered Study Guides, Structured Learning, Multi-Language Support) using `_WelcomeFeatureItem` widgets.
-   **Authentication Options**:
    -   **"Login with Google"**: Navigates to the `/login` route, which is handled by the `Auth` module for Google OAuth.
    -   **"Continue as Guest"**: Initiates an anonymous sign-up process directly with Supabase.
-   **Guest Login Logic (`_loginAsGuest`)**:
    -   Makes an HTTP POST request to Supabase's anonymous signup endpoint.
    -   Parses the response to extract the `access_token` and `user_id`.
    -   Securely stores the `auth_token`, `user_type` ('guest'), `user_id`, and marks `onboarding_completed` as `true` in `flutter_secure_storage` and `Hive`.
    -   Navigates to the home screen (`/`) upon successful guest login.
    -   Handles various error scenarios (network, API response parsing, storage) and displays informative dialogs.
-   **Loading States**: Manages `_isGuestLoginLoading` and `_isGoogleLoginLoading` to provide visual feedback during authentication attempts.
-   **Privacy Notice**: Displays a notice about agreeing to Terms of Service and Privacy Policy.

### 2.3. `OnboardingLanguagePage` (`presentation/pages/onboarding_language_page.dart`)

This page allows users to select their preferred language for the application.

**Key Responsibilities:**

-   **Language Selection**: Presents options for English, Hindi, and Malayalam using `_LanguageOption` widgets.
-   **Persistence**: Loads and saves the selected language preference to `Hive.box('app_settings')`.
-   **Navigation**: Navigates to `OnboardingPurposePage` upon continuing.

### 2.4. `OnboardingPurposePage` (`presentation/pages/onboarding_purpose_page.dart`)

This page explains the core purpose and "how it works" of the app, focusing on the AI-powered study guide generation.

**Key Responsibilities:**

-   **Feature Explanation**: Visually explains the three steps of using the app (Choose Input, AI Generation, Study & Apply) using `_StepItem` widgets.
-   **Onboarding Completion**: Marks `onboarding_completed` as `true` in `Hive` upon pressing "Get Started".
-   **Navigation**: Navigates to the home screen (`/`) after completing this step.

## 3. Data Flows

1.  **Initial App Launch**:
    -   The app's routing logic (likely in `main.dart` or a routing configuration file) checks if `onboarding_completed` is `true` in `Hive`.
    -   If `false`, the user is directed to `OnboardingScreen`.
2.  **`OnboardingScreen` Flow**:
    -   User swipes through the three introductory slides.
    -   Tapping "Continue" or "Get Started" (on the last slide) navigates to `OnboardingWelcomePage`.
3.  **`OnboardingWelcomePage` Flow**:
    -   **"Login with Google"**: Triggers navigation to the `/login` route, which is handled by the `Auth` module. The `Auth` module then takes over the Google OAuth flow.
    -   **"Continue as Guest"**:
        -   An HTTP POST request is sent to the Supabase anonymous signup API.
        -   The response (containing `access_token`, `user_id`) is parsed.
        -   These details, along with `user_type` and `onboarding_completed` flag, are saved to `flutter_secure_storage` and `Hive`.
        -   The user is then redirected to the home screen (`/`).
4.  **Language and Purpose Flow (Alternative/Sub-flows)**:
    -   `OnboardingLanguagePage` allows language selection, saving it to `Hive`.
    -   `OnboardingPurposePage` explains app functionality and marks onboarding as complete in `Hive` before navigating to the home screen.

## 4. Persistence

The onboarding module heavily relies on `Hive` (a local NoSQL database) and `flutter_secure_storage` for persisting user preferences and onboarding status:

-   `selected_language`: Stores the user's chosen language.
-   `onboarding_completed`: A boolean flag indicating whether the onboarding process has been finished. This is crucial for determining if the onboarding screens should be shown on subsequent app launches.
-   `auth_token`, `user_type`, `user_id`: Stored in `flutter_secure_storage` for guest users to maintain their session.

## 5. Localization

The `OnboardingLanguagePage` explicitly uses `AppLocalizations.of(context)` to fetch localized strings for titles, subtitles, and language names, indicating support for multiple languages (English, Hindi, Malayalam).

## 6. Potential Improvements/Considerations

-   **Unified Authentication Handling**: The `OnboardingWelcomePage` directly handles anonymous guest login via HTTP requests and `flutter_secure_storage`, while Google login is delegated to the `Auth` module. For consistency and maintainability, it might be beneficial to centralize all authentication logic within the `Auth` module, with the `OnboardingWelcomePage` only dispatching events to an `AuthBloc` (or similar) for both guest and Google sign-in. This would reduce code duplication and improve separation of concerns.
-   **Error Handling for Guest Login**: While error dialogs are shown, the error messages could be more user-friendly and less technical.
-   **Onboarding Completion Flag**: The `onboarding_completed` flag is stored in both `Hive` and `flutter_secure_storage`. It might be sufficient to store it in just one place (e.g., `Hive` for general app settings) to avoid potential inconsistencies.
-   **Visual Consistency**: Ensure all onboarding pages maintain a consistent visual style and branding.
-   **Accessibility**: Review for accessibility features, such as proper semantic labeling and navigation for screen readers.

This summary provides a comprehensive understanding of the onboarding module's design and functionality.
