# Frontend Codebase Guide: Architecture and Reading Flutter Code

This guide provides a deeper dive into the architectural patterns and conventions used in the Flutter frontend, offering a roadmap for understanding and navigating the codebase.

## 1. Overall Architectural Pattern

The frontend project largely adheres to a **Clean Architecture** or a similar layered approach, emphasizing separation of concerns, testability, and maintainability. The primary layers are:

-   **Presentation Layer (`lib/features/<feature_name>/presentation`):**
    -   **Responsibility:** Handles the UI, user interactions, and presentation logic. It receives user input, displays data, and communicates with the Domain Layer.
    -   **Components:** Widgets (UI elements), ViewModels/Providers (state management and presentation logic), and Pages/Screens.
    -   **Dependencies:** Depends on the Domain Layer. It should **not** directly depend on the Data Layer.

-   **Domain Layer (`lib/features/<feature_name>/domain` or `lib/core/usecases`):**
    -   **Responsibility:** Contains the core business logic and entities. It is the most stable layer and should be independent of other layers.
    -   **Components:** Entities (business objects), Use Cases/Interactors (application-specific business rules), and Repositories Interfaces (contracts for data access).
    -   **Dependencies:** Has no dependencies on other layers (pure Dart code).

-   **Data Layer (`lib/features/<feature_name>/data` or `lib/core/network`):**
    -   **Responsibility:** Handles data retrieval and storage from various sources (APIs, local storage, etc.). It implements the Repository Interfaces defined in the Domain Layer.
    -   **Components:** Data Models (for serialization/deserialization), Data Sources (abstracting external APIs or databases), and Repository Implementations.
    -   **Dependencies:** Depends on the Domain Layer (to implement its interfaces) and external packages for networking/storage.

-   **Core Layer (`lib/core`):**
    -   **Responsibility:** Contains cross-cutting concerns and foundational utilities that are shared across multiple features or layers. This includes dependency injection setup, error handling, networking clients, and common UI components.
    -   **Components:** `config`, `constants`, `di`, `error`, `localization`, `network`, `presentation` (base classes), `router`, `services`, `theme`, `usecases` (abstract base classes), `utils`.
    -   **Dependencies:** Generally independent, or depends on external packages.

## 2. Internal Structure of a Feature

As noted in `project_structure.md`, each feature within `lib/features` is a self-contained module. A typical feature (`lib/features/<feature_name>`) will often follow this internal structure, mirroring the architectural layers:

```
lib/features/<feature_name>/
├── presentation/
│   ├── widgets/        // Reusable UI components specific to this feature
│   ├── pages/          // Main screens/pages of the feature
│   └── viewmodels/     // State management logic (e.g., using Provider, BLoC, Riverpod)
├── domain/
│   ├── entities/       // Data structures representing business objects
│   ├── repositories/   // Abstract interfaces for data operations
│   └── usecases/       // Business logic operations
└── data/
    ├── models/         // Data models for API/DB interaction (e.g., from JSON)
    ├── datasources/    // Implementations for fetching data (e.g., API client)
    └── repositories/   // Implementations of domain repository interfaces
```

## 3. How to Read the Flutter Code

When approaching a new feature or trying to understand existing functionality, consider the following:

1.  **Start from the UI (Presentation Layer):**
    -   Begin by looking at the `pages/` or `widgets/` within a feature's `presentation` directory. These files define what the user sees.
    -   Identify how user interactions (button taps, text input) are handled. They typically trigger methods in a `viewmodel` or directly call `usecases`.

2.  **Follow the Flow to the Domain Layer:**
    -   From the `viewmodel`, trace the calls to the `usecases/` in the `domain` layer. Use cases encapsulate specific business rules (e.g., `LoginUserUseCase`, `GenerateStudyGuideUseCase`).
    -   Understand what data (`entities/`) these use cases operate on and what `repositories/` interfaces they depend on.

3.  **Dive into the Data Layer (if needed):**
    -   If a use case requires data, it will call a method on a `repository` interface. The actual implementation of this interface is found in the `data/repositories/` directory.
    -   These repository implementations will then interact with `datasources/` (e.g., `ApiDataSource`, `LocalDataSource`) to fetch or store data. Data models (`models/`) are used for serialization/deserialization.

4.  **Understand Core Utilities:**
    -   Be aware of the `lib/core` directory. Common functionalities like networking (`network/`), error handling (`error/`), and dependency injection (`di/`) are defined here and used across features.

### Key Flutter Concepts in this Project:

-   **Widgets:** Everything in Flutter is a widget. Understand the difference between `StatelessWidget` (for static UI) and `StatefulWidget` (for dynamic UI that changes over time).
-   **State Management:** This project likely uses a specific state management solution (e.g., Provider, BLoC, Riverpod, GetX). Look for `ChangeNotifierProvider`, `BlocProvider`, or similar patterns to understand how UI state is managed and updated.
-   **Asynchronous Operations:** Network requests and other long-running tasks are asynchronous. Look for `async`/`await` keywords and `Future` types. Error handling for these operations is crucial.
-   **Dependency Injection:** The `lib/core/di` directory is where dependencies are registered and resolved. This makes components more testable and interchangeable.

## 4. Walkthrough Approach

To effectively understand a feature:

1.  **Identify the Entry Point:** Find the main `Page` or `Screen` widget for the feature (e.g., `home_page.dart`, `login_screen.dart`).
2.  **Examine the `ViewModel` (or equivalent):** Understand how the UI interacts with its state management logic. What data does it expose? What actions can it perform?
3.  **Trace `Use Cases`:** Follow the calls from the `ViewModel` to the `domain/usecases` to grasp the core business logic.
4.  **Review `Repository` Implementations:** If data persistence or external interaction is involved, examine the `data/repositories` and `data/datasources` to see how data is fetched and manipulated.
5.  **Check `Core` Dependencies:** Note any imports from `lib/core` to understand shared utilities and configurations.
6.  **Run and Debug:** The best way to understand code is to see it in action. Use Flutter's debugging tools to step through the code and observe the flow of data and execution.

By following this guide, you should be able to effectively navigate and comprehend the Flutter frontend codebase.