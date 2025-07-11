# `user_profiles` Table Definition

**Purpose:** Extends the `auth.users` table to store user-specific preferences and application-level metadata.

| Column Name         | Data Type                | Description                                                                 |
| ------------------- | ------------------------ | --------------------------------------------------------------------------- |
| `id`                | `UUID` (Primary Key)     | Foreign key referencing `auth.users(id)`. Ensures a one-to-one relationship. |
| `language_preference` | `VARCHAR(5)`             | User's preferred language for the application UI and content (e.g., 'en', 'hi'). Default: `'en'`. |
| `theme_preference`  | `VARCHAR(20)`            | User's preferred theme (e.g., 'light', 'dark'). Default: `'light'`.          |
| `is_admin`          | `BOOLEAN`                | Flag indicating if the user has administrative privileges. Default: `false`.      |
| `created_at`        | `TIMESTAMP WITH TIME ZONE` | Timestamp of when the user profile was created. Default: `NOW()`.           |
| `updated_at`        | `TIMESTAMP WITH TIME ZONE` | Timestamp of the last time the user profile was updated. Default: `NOW()`.    |
