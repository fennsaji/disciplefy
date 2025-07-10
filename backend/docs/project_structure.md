
# Backend Project Structure

This document outlines the structure of the backend codebase, which is built on top of Supabase. Understanding this structure is crucial for developers to contribute effectively to the project.

## High-Level Overview

The backend is organized within the `supabase` directory, which contains all the necessary files for the database, authentication, and serverless functions.

## Core Directories

The key directories within the `supabase` directory are:

-   `functions`: This directory contains the serverless functions that power the application's business logic. Each subdirectory corresponds to a specific function.
-   `migrations`: Database schema migrations are stored here. Each SQL file represents a version of the database schema.
-   `policies`: This directory contains the Row Level Security (RLS) policies for the database tables.
-   `templates`: Email templates for authentication and other purposes are stored here.

## Key Files

-   `config.toml`: The main configuration file for the Supabase project.
-   `test_auth_flows.sh`: A shell script for testing authentication flows.
-   `test_commands.md`: A markdown file with test commands.

## Functions

The `functions` directory contains the following serverless functions:

-   `_shared`: Shared code that can be used by other functions.
-   `auth-google-callback`: Handles the Google authentication callback.
-   `auth-session`: Manages user sessions.
-   `daily-verse`: Fetches the daily Bible verse.
-   `feedback`: Handles user feedback.
-   `study-generate`: Generates study guides.
-   `study-guides`: Manages study guides.
-   `topics-recommended`: Provides recommended topics.

By organizing the project in this way, we aim for a clean, scalable, and maintainable backend codebase.
