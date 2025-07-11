# `recommended_guide_sessions` Table Definition

**Purpose:** Stores the state of multi-step recommended guide sessions for users.

| Column Name                      | Data Type                | Description                                                                                                |
| -------------------------------- | ------------------------ | ---------------------------------------------------------------------------------------------------------- |
| `id`                             | `UUID` (Primary Key)     | Unique identifier for the session.                                                                         |
| `user_id`                        | `UUID`                   | Foreign key referencing `auth.users(id)`.                                                                  |
| `topic`                          | `VARCHAR(100)`           | The topic of the recommended guide session.                                                                |
| `current_step`                   | `INTEGER`                | The user's current step in the session (1-4). Default: `1`.                                                  |
| `step_1_context`                 | `TEXT`                   | Content for step 1 of the session.                                                                         |
| `step_2_scholar_guide`           | `TEXT`                   | Content for step 2 of the session.                                                                         |
| `step_3_group_discussion`        | `TEXT`                   | Content for step 3 of the session.                                                                         |
| `step_4_application`             | `TEXT`                   | Content for step 4 of the session.                                                                         |
| `step_1_completed_at`            | `TIMESTAMP WITH TIME ZONE` | Timestamp for when step 1 was completed.                                                                   |
| `step_2_completed_at`            | `TIMESTAMP WITH TIME ZONE` | Timestamp for when step 2 was completed.                                                                   |
| `step_3_completed_at`            | `TIMESTAMP WITH TIME ZONE` | Timestamp for when step 3 was completed.                                                                   |
| `step_4_completed_at`            | `TIMESTAMP WITH TIME ZONE` | Timestamp for when step 4 was completed.                                                                   |
| `completion_status`              | `BOOLEAN`                | A flag indicating whether the entire session is complete. Default: `false`.                                |
| `language`                       | `VARCHAR(5)`             | The language of the session content. Default: `'en'`.                                                      |
| `created_at`                     | `TIMESTAMP WITH TIME ZONE` | Timestamp of when the session was created. Default: `NOW()`.                                               |
| `updated_at`                     | `TIMESTAMP WITH TIME ZONE` | Timestamp of the last time the session was updated. Default: `NOW()`.                                      |
