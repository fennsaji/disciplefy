# `feedback` Table Definition

**Purpose:** Stores user feedback related to study guides or recommended guide sessions.

| Column Name                  | Data Type                | Description                                                                                                |
| ---------------------------- | ------------------------ | ---------------------------------------------------------------------------------------------------------- |
| `id`                         | `UUID` (Primary Key)     | Unique identifier for the feedback entry.                                                                  |
| `study_guide_id`             | `UUID`                   | Foreign key referencing `study_guides(id)`. Null if feedback is for a recommended guide session.           |
| `recommended_guide_session_id` | `UUID`                   | Foreign key referencing `recommended_guide_sessions(id)`. Null if feedback is for a study guide.           |
| `user_id`                    | `UUID`                   | Foreign key referencing `auth.users(id)`. Associates the feedback with a specific user.                    |
| `was_helpful`                | `BOOLEAN`                | Indicates whether the associated content was helpful (`true`) or not (`false`).                            |
| `message`                    | `TEXT`                   | Optional detailed feedback message from the user.                                                          |
| `category`                   | `VARCHAR(50)`            | Category of the feedback (e.g., 'general', 'bug', 'suggestion'). Default: `'general'`.                   |
| `sentiment_score`            | `FLOAT`                  | A sentiment score for the feedback, ranging from -1.0 (negative) to 1.0 (positive).                        |
| `created_at`                 | `TIMESTAMP WITH TIME ZONE` | Timestamp of when the feedback was submitted. Default: `NOW()`.                                            |
| `CONSTRAINT feedback_reference_check` |                  | Ensures that a feedback entry references either a `study_guide_id` OR a `recommended_guide_session_id`, but not both. |