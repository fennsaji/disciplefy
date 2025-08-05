# 📡 Disciplefy API List

---

## 👤 User APIs

* `GET /users/me` – Get current user profile
* `PATCH /users/me` – Update own profile (name, photo)

---

## 🧑‍🧒 Fellowship APIs

* `POST /fellowships` – Create a new fellowship (Mentor only).
* `GET /fellowships` – Get fellowships current user belongs to
* `GET /fellowships/:id` – Get fellowship details
* `GET /fellowships/:id/members` – Get list of all members in a fellowship.
* `POST /fellowships/:id/members` – Add user directly by ID/email (Mentor only)
* `DELETE /fellowships/:id/members/:userId` – Remove a member from fellowship (Mentor only)

---

## 🧣 Discipleship Path APIs

* `GET /discipleship_paths` – Get all paths
* `GET /discipleship_paths/:id/lessons` – Get lessons for a path
* `POST /discipleship_paths/:id/start` – User starts a path (must be in fellowship)
* `PATCH /discipleship_paths/:pathId/lessons/:lessonId/complete` – Mark lesson complete (user-level progress)
* `GET /discipleship_paths/:id/progress` – Get current user's progress in the path

---

## 📓 Fellowship Discipleship Progress APIs (Mentor Controlled)

* `GET /fellowships/:id/progress` – Get discipleship progress for the fellowship (all members' aggregated progress)
* `PATCH /fellowships/:id/progress/lessons/:lessonId` – Mark lesson as complete for the entire fellowship (Mentor only)
* `DELETE /fellowships/:id/progress/lessons/:lessonId` – Unmark lesson as complete for the fellowship (Mentor only)

---

## 🔹 Mentor Promotion Logic

* A user is promoted to "Mentor" role **only if**:

  * Their **own discipleship path** is completed AND
  * At least one **fellowship** they are part of has completed the discipleship path (as marked by that fellowship's mentor)
