-- Study content language (the language study guides/topics generate in) was
-- device-local only, never reaching the server. Push notifications that
-- trigger study generation stamped the user's UI language into the payload
-- instead — a user with English UI and Malayalam content language got an
-- English guide from a notification tap. NULL means "follow app language",
-- matching the frontend's 'default' sentinel.

ALTER TABLE user_profiles
  ADD COLUMN study_content_language VARCHAR(5);

COMMENT ON COLUMN user_profiles.study_content_language IS
'Language for study guide/topic content, independent of language_preference (the UI language). NULL means follow language_preference.';
