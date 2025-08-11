# Disciplefy API List

## 👤 User APIs
- **GET** `/users/me` – Get the current user's profile.
- **PATCH** `/users/me` – Update own profile (name, photo, etc.).

---

## 🧑‍🤝‍🧑 Fellowship APIs
- **POST** `/fellowships` – Create a new fellowship *(Mentor only)*.
- **GET** `/fellowships` – Get all fellowships the current user belongs to.
- **GET** `/fellowships/:id` – Get details for a specific fellowship.
- **GET** `/fellowships/:id/members` – List all members of a fellowship.
- **POST** `/fellowships/:id/members` – Add a user by ID or email *(Mentor only)*.
- **DELETE** `/fellowships/:id/members/:userId` – Remove a member from a fellowship *(Mentor only)*.

---

## 📖 Discipleship Path APIs
- **GET** `/discipleship_paths` – Get all available discipleship paths.
- **GET** `/discipleship_paths/:id` – Get details for a specific discipleship path.
- **GET** `/discipleship_paths/:id/lessons` – Get all lessons in a path.
- **POST** `/discipleship_paths/:id/start` – Start a discipleship path *(must be part of a fellowship)*.
- **PATCH** `/discipleship_paths/:pathId/lessons/:lessonId/complete` – Mark a lesson complete for the current user.
- **GET** `/discipleship_paths/:id/progress` – Get the current user's progress in a path.

---

## 📓 Fellowship Discipleship Progress APIs *(Mentor Controlled)*
- **GET** `/fellowships/:id/progress` – Get discipleship progress for all members in the fellowship.
- **PATCH** `/fellowships/:id/progress/lessons/:lessonId` – Mark a lesson as complete for the entire fellowship.
- **DELETE** `/fellowships/:id/progress/lessons/:lessonId` – Unmark a lesson as complete for the entire fellowship.

---
