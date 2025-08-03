# 📡 Disciplefy API List

---

## 👤 User APIs

* `GET /users/me` – Get current user profile
* `PATCH /users/me` – Update own profile (name, photo)

---

## 🧑‍🤝‍🧑 Fellowship APIs

* `POST /fellowships` – Create a new fellowship (Mentor only).
* `GET /fellowships` – Get fellowships current user belongs to
* `GET /fellowships/:id` – Get fellowship details
* `GET /fellowships/:id/members` – Get list of all members in a fellowship.
* `POST /fellowships/:id/members` – Add user directly by ID/email (Mentor only)
* `DELETE /fellowships/:id/members/:userId` – Remove a member from fellowship (Mentor only)

---

## 🧭 Discipleship Path APIs

* `GET /discipleship_paths` – Get all paths
* `GET /discipleship_paths/:id/lessons` – Get lessons for a path
* `POST /discipleship_paths/:id/start` – User starts a path (must be in fellowship)
* `PATCH /discipleship_paths/:pathId/lessons/:lessonId/complete` – Mark lesson complete
* `GET /discipleship_paths/:id/progress` – Get current user's progress in the path

---

## 📓 Journal APIs

* `POST /journals` – Create a journal entry
* `GET /journals` – List own journal entries
* `GET /journals/:id` – View specific journal
* `PATCH /journals/:id` – Edit journal entry
* `DELETE /journals/:id` – Delete journal entry

---

## 💰 Donation / Unlock APIs

* `POST /donate` – Submit a donation (via Razorpay/Stripe etc.)
* `GET /donate/status` – Check if donation > ₹1000 (unlocks unlimited access)
