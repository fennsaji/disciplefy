# Disciplefy Table Schemas

## users
| Field         | Type       | Description                                         |
|---------------|------------|-----------------------------------------------------|
| id            | uuid       | Primary key                                         |
| email         | text       | Unique user email                                   |
| name          | text       | Display name                                        |
| role          | text       | user / member / mentor / admin                      |
| created_at    | timestamp  | Timestamp when account was created                  |

---

## discipleship_paths
| Field         | Type       | Description                                         |
|---------------|------------|-----------------------------------------------------|
| id            | uuid       | Primary key                                         |
| title         | text       | Path name                                           |
| description   | text       | Description of the path                             |
| sequence      | integer    | Order of appearance in progression                  |
| created_at    | timestamp  | Timestamp when the path was created                 |

---

## lessons
| Field         | Type       | Description                                         |
|---------------|------------|-----------------------------------------------------|
| id            | uuid       | Primary key                                         |
| path_id       | uuid       | FK to discipleship_paths                             |
| title         | text       | Lesson title                                        |
| content       | text       | Lesson devotional/teaching content                  |
| journal_prompt| text       | Optional journaling prompt                          |
| sequence      | integer    | Order of appearance within the path                  |
| created_at    | timestamp  | Timestamp when the lesson was created               |

---

## user_path_progress
| Field         | Type       | Description                                         |
|---------------|------------|-----------------------------------------------------|
| id            | uuid       | Primary key                                         |
| user_id       | uuid       | FK to users                                         |
| path_id       | uuid       | FK to discipleship_paths                             |
| lesson_id     | uuid       | FK to lessons                                       |
| completed_at  | timestamp  | Timestamp when lesson was completed                 |

---

## fellowships
| Field         | Type       | Description                                         |
|---------------|------------|-----------------------------------------------------|
| id            | uuid       | Primary key                                         |
| name          | text       | Fellowship name                                     |
| mentor_id     | uuid       | FK to users (mentor/creator)                        |
| created_at    | timestamp  | Timestamp when the fellowship was created           |

---

## fellowship_members
| Field         | Type       | Description                                         |
|---------------|------------|-----------------------------------------------------|
| id            | uuid       | Primary key                                         |
| fellowship_id | uuid       | FK to fellowships                                   |
| user_id       | uuid       | FK to users                                         |
| role          | text       | mentor / member                                     |
| joined_at     | timestamp  | Timestamp when the user joined the fellowship       |

---

## fellowship_path_progress
| Field         | Type       | Description                                         |
|---------------|------------|-----------------------------------------------------|
| id            | uuid       | Primary key                                         |
| fellowship_id | uuid       | FK to fellowships                                   |
| path_id       | uuid       | FK to discipleship_paths                             |
| lesson_id     | uuid       | FK to lessons                                       |
| completed_at  | timestamp  | Timestamp when lesson was marked complete by mentor |

