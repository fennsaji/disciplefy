
# Frontend Project Structure

This document outlines the structure of the frontend codebase, built with Flutter. Understanding this structure is key for developers to contribute effectively.

## High-Level Overview

The `lib` directory is the heart of the Flutter application and is organized into two main subdirectories:

-   `core`: Contains the foundational building blocks of the application. These are generic modules that can be reused across different features.
-   `features`: This directory holds the different modules or "features" of the application. Each feature is a self-contained unit of functionality.

The `main.dart` file is the entry point of the application.

## Core Directory

The `core` directory contains the following subdirectories:

-   `config`: Application-level configurations.
-   `constants`: Application-wide constants, such as strings, numbers, etc.
-   `debug`: Tools for debugging the application.
-   `di`: Dependency injection setup.
-   `error`: Error handling mechanisms, including custom exceptions and failure classes.
-   `localization`: Internationalization and localization files.
-   `network`: Networking layer, including API clients and data sources.
-   `presentation`: Base classes for presentation layer, like base widgets, view models, etc.
-   `router`: Application's navigation and routing logic.
-   `services`: Cross-cutting services like analytics, crash reporting, etc.
-   `theme`: Application's theme and styling.
-   `usecases`: Abstract classes for use cases.
-   `utils`: Utility functions and helper classes.

## Features Directory

The `features` directory is where the main functionalities of the app reside. Each feature is organized as a separate module and follows a similar internal structure.

The current features are:

-   `auth`: User authentication (login, registration, etc.).
-   `daily_verse`: Displays the daily Bible verse.
-   `home`: The main screen of the application after login.
-   `onboarding`: The initial screens shown to a new user.
-   `saved_guides`: Lists the user's saved study guides.
-   `settings`: User-specific settings and preferences.
-   `study_generation`: The feature for generating new study guides.

By organizing the project in this way, we aim for a clean, scalable, and maintainable codebase.
