# Disciplefy Table Schemas

## users
| Field         | Type       | Description                            |
|---------------|------------|----------------------------------------|
| id            | uuid       | Primary key                            |
| email         | text       | Unique user email                      |
| name          | text       | Display name                           |
| role          | text       | user / member / mentor / admin         |
| created_at    | timestamp  | Timestamp of account creation          |

---

## discipleship_paths
| Field         | Type       | Description                            |
|---------------|------------|----------------------------------------|
| id            | uuid       | Primary key                            |
| title         | text       | Name of the path                       |
| description   | text       | Path description                       |
| sequence      | integer    | Order in the progression               |

---

## lessons
| Field         | Type       | Description                            |
|---------------|------------|----------------------------------------|
| id            | uuid       | Primary key                            |
| path_id       | uuid       | FK to discipleship_paths               |
| title         | text       | Lesson title                           |
| content       | text       | Text-based devotion                    |
| journal_prompt| text       | Optional prompt for journaling         |
| sequence      | integer    | Order within the path                  |

---

## user_path_progress
| Field         | Type       | Description                            |
|---------------|------------|----------------------------------------|
| id            | uuid       | Primary key                            |
| user_id       | uuid       | FK to users                            |
| path_id       | uuid       | FK to discipleship_paths               |
| lesson_id     | uuid       | FK to lessons                          |
| completed_at  | timestamp  | When the lesson was completed          |

---

## fellowships
| Field         | Type       | Description                            |
|---------------|------------|----------------------------------------|
| id            | uuid       | Primary key                            |
| name          | text       | Fellowship name                        |
| mentor_id     | uuid       | FK to users (creator/mentor)           |
| created_at    | timestamp  | When the fellowship was created        |

---

## fellowship_members
| Field         | Type       | Description                            |
|---------------|------------|----------------------------------------|
| id            | uuid       | Primary key                            |
| fellowship_id | uuid       | FK to fellowships                      |
| user_id       | uuid       | FK to users                            |
| role          | text       | mentor / member                        |
| joined_at     | timestamp  | When user joined the fellowship        |

---

## journals
| Field         | Type       | Description                            |
|---------------|------------|----------------------------------------|
| id            | uuid       | Primary key                            |
| user_id       | uuid       | FK to users                            |
| lesson_id     | uuid       | FK to lessons                          |
| content       | text       | Journal entry                          |
| created_at    | timestamp  | When journal was written               |
