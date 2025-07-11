# `study_guides` Table Definition

**Purpose:** Stores personalized Bible study guides generated for authenticated users.

| Column Name            | Data Type                | Description                                                                                              |
| ---------------------- | ------------------------ | -------------------------------------------------------------------------------------------------------- |
| `id`                   | `UUID` (Primary Key)     | Unique identifier for the study guide.                                                                   |
| `user_id`              | `UUID`                   | Foreign key referencing `auth.users(id)`. Associates the guide with a specific user.                     |
| `input_type`           | `VARCHAR(20)`            | The type of input used for generation, either 'scripture' or 'topic'.                                      |
| `input_value`          | `VARCHAR(255)`           | The specific scripture reference or topic provided by the user.                                          |
| `summary`              | `TEXT`                   | A concise summary of the study guide's content.                                                          |
| `interpretation`       | `TEXT`                   | In-depth interpretation of the scripture or topic. Added in a later migration.                           |
| `context`              | `TEXT`                   | Historical and theological context for the scripture or topic.                                           |
| `related_verses`       | `TEXT[]`                 | An array of related Bible verses.                                                                        |
| `reflection_questions` | `TEXT[]`                 | An array of questions to prompt reflection and discussion.                                               |
| `prayer_points`        | `TEXT[]`                 | An array of prayer points related to the study guide.                                                    |
| `language`             | `VARCHAR(5)`             | The language in which the guide was generated (e.g., 'en', 'hi'). Default: `'en'`.                         |
| `is_saved`             | `BOOLEAN`                | A flag indicating whether the user has saved this guide for future reference. Default: `false`.          |
| `created_at`           | `TIMESTAMP WITH TIME ZONE` | Timestamp of when the study guide was created. Default: `NOW()`.                                         |
| `updated_at`           | `TIMESTAMP WITH TIME ZONE` | Timestamp of the last time the study guide was updated (e.g., when saved). Default: `NOW()`.             |