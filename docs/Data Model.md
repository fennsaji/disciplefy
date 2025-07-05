# **📘 Key Entities and Relationships (Defeah Bible Study)**

## **🧑‍💼 User**

  -----------------------------------------------------------------------
  **Field**         **Type**       **Description**
  ----------------- -------------- --------------------------------------
  id                UUID           Unique identifier

  name              String         Optional user name

  email             String         Optional user email

  auth_provider     String         Google, Apple, Anonymous, etc.

  created_at        Timestamp      User registration timestamp
  -----------------------------------------------------------------------

## **📝 StudyQuery**

  ------------------------------------------------------------------------
  **Field**     **Type**     **Description**
  ------------- ------------ ---------------------------------------------
  id            UUID         Unique query request ID

  user_id       UUID         Foreign key to User (nullable for anonymous)

  input_type    Enum         \"verse\" or \"topic\"

  input_value   String       e.g., "faith" or "Romans 12:1"

  language      String       ISO language code (e.g., en, hi)

  created_at    Timestamp    Time of guide generation request
  ------------------------------------------------------------------------

## **📖 StudyGuide**

  ---------------------------------------------------------------------------
  **Field**              **Type**   **Description**
  ---------------------- ---------- -----------------------------------------
  id                     UUID       Unique study guide ID

  summary                Text       Summary paragraph

  explanation            Text       Expanded explanation or theological note

  related_verses         Array      List of scripture references

  reflection_questions   Array      List of reflection questions

  prayer_points          Array      List of prayer/action points

  language               String     Language of this guide
  ---------------------------------------------------------------------------

## **⭐ SavedGuide**

  --------------------------------------------------------------------------
  **Field**        **Type**    **Description**
  ---------------- ----------- ---------------------------------------------
  id               UUID        Unique saved guide ID

  user_id          UUID        Foreign key to User

  study_guide_id   UUID        Foreign key to StudyGuide

  saved_at         Timestamp   Timestamp when user saved/bookmarked this
                               guide
  --------------------------------------------------------------------------

## **📐 Normalization Plan**

- Fully normalized (3NF) schema

- Clear separation between user intent (StudyQuery) and generated output
  (StudyGuide)

- Avoids duplication: the same StudyGuide can be referenced by multiple
  SavedGuides

- Minimal user metadata for privacy and performance

- Localized StudyGuide allows multi-language reuse across users

Let me know if you'd like this converted into an ERD visual or SQL
schema next.
