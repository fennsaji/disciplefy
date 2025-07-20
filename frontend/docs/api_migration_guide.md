# Frontend API Migration Guide (v1.2)

**Date**: July 20, 2025

This document provides a comprehensive guide for frontend developers to update the Flutter application's API integrations to align with the latest backend API reference (`api_reference.md`, version 1.2).

## 1. High-Level Changes

The most significant changes in this API version are the standardization of authentication, the introduction of new endpoints, and a consistent response format.

-   **JWT-Based Authentication**: The `user_context` object has been **removed** from the `study-generate` request body. User identification is now handled exclusively and securely on the backend via the `Authorization: Bearer <YOUR_ACCESS_TOKEN>` header.
-   **Standardized Responses**: All API endpoints now return a consistent JSON structure: `{ "success": boolean, "data": {...} }` for success and `{ "success": false, "error": "...", "message": "..." }` for errors.
-   **New Endpoints**: New endpoints have been introduced, such as `/daily-verse` and `/study-guides`, which require new service implementations on the frontend.
-   **Custom Anonymous Sessions**: A new endpoint `/auth-session` is introduced for managing anonymous sessions, replacing the direct call to Supabase's built-in anonymous sign-in.

## 2. Endpoint-by-Endpoint Migration Guide

This section details the required changes for each feature's data layer.

### 2.1. Study Guide Generation

**Endpoint**: `POST /functions/v1/study-generate`

-   **What Changed**: The `user_context` object has been removed from the request body.
-   **File to Update**: `frontend/lib/features/study_generation/data/repositories/study_repository_impl.dart`
-   **Status**: ✅ **Already compliant.** The current implementation does not send `user_context`. No changes are needed, but this confirms alignment with the new API.

**Code for reference (no changes needed):**
```dart
// frontend/lib/features/study_generation/data/repositories/study_repository_impl.dart
final response = await _supabaseClient.functions.invoke(
  'study-generate',
  body: {
    'input_type': inputType,
    'input_value': input,
    'language': language,
  }, // No user_context, which is correct.
  headers: headers,
);
```

### 2.2. Daily Verse

**Endpoint**: `GET /functions/v1/daily-verse`

-   **What Changed**: This is a new endpoint. The API response for translations uses full language names (`"hindi"`, `"malayalam"`) instead of language codes (`"hi"`, `"ml"`).
-   **Files to Update**:
    1.  `frontend/lib/features/daily_verse/data/models/daily_verse_model.dart`
    2.  `frontend/lib/features/daily_verse/data/services/daily_verse_api_service.dart`

-   **Action Required**:
    1.  Update the `DailyVerseTranslationsModel` to correctly map the API response keys using `@JsonKey`.
    2.  Ensure `DailyVerseApiService` correctly parses the new standardized response structure.

**Code Modifications:**

1.  **Update `daily_verse_model.dart`:**

    **Before:**
    ```dart
    @JsonSerializable()
    class DailyVerseTranslationsModel {
      final String esv;
      final String hi;
      final String ml;
      // ...
    }
    ```

    **After:**
    ```dart
    @JsonSerializable()
    class DailyVerseTranslationsModel {
      final String esv;
      @JsonKey(name: 'hindi')
      final String hi;
      @JsonKey(name: 'malayalam')
      final String ml;
      // ...
    }
    ```
    *Note: After changing the model, you must run the build runner to regenerate the `.g.dart` file: `flutter pub run build_runner build --delete-conflicting-outputs`*

2.  **Update `daily_verse_api_service.dart`:**

    The `_parseVerseResponse` method should be updated to robustly handle the new `success` and `data` fields.

    **Before:**
    ```dart
    Either<Failure, DailyVerseEntity> _parseVerseResponse(String responseBody) {
      try {
        final DailyVerseResponse verseResponse = DailyVerseResponse.fromJson(json.decode(responseBody));
        return Right(verseResponse.data.toEntity());
      } catch (e) {
        // ...
      }
    }
    ```

    **After (Recommended):**
    ```dart
    Either<Failure, DailyVerseEntity> _parseVerseResponse(String responseBody) {
      try {
        final Map<String, dynamic> jsonData = json.decode(responseBody);
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final DailyVerseModel verseModel = DailyVerseModel.fromJson(jsonData['data']);
          return Right(verseModel.toEntity());
        } else {
          return Left(ServerFailure(
            message: jsonData['message'] ?? 'API returned failure response',
          ));
        }
      } catch (e) {
        return Left(ServerFailure(
          message: 'Failed to parse daily verse response: $e',
        ));
      }
    }
    ```

### 2.3. Get Recommended Topics

**Endpoint**: `GET /functions/v1/topics-recommended`

-   **What Changed**: The API response structure is now standardized with `success` and `data` fields.
-   **File to Update**: `frontend/lib/features/home/data/services/recommended_guides_service.dart`
-   **Status**: ✅ **Already compliant.** The `_parseTopicsResponse` method correctly handles the new response wrapper. No changes are needed.

### 2.4. Anonymous Sessions

**Endpoint**: `POST /functions/v1/auth-session`

-   **What Changed**: The backend now provides a custom endpoint for creating and managing anonymous sessions. The frontend currently uses Supabase's built-in `signInAnonymously()`. This should be migrated to use the new endpoint for consistency and to leverage any custom backend logic.
-   **File to Update**: `frontend/lib/features/auth/data/services/auth_service.dart`
-   **Action Required**: Modify the `signInAnonymously` method to call the new `/functions/v1/auth-session` Edge Function.

**Code Modification:**

In `AuthService.signInAnonymously`:

**Before:**
```dart
Future<bool> signInAnonymously() async {
  try {
    await _supabase.auth.signInAnonymously();
    // ...
    return true;
  } catch (e) {
    // ...
  }
}
```

**After:**
```dart
Future<bool> signInAnonymously() async {
  try {
    final response = await _supabase.functions.invoke(
      'auth-session',
      body: {
        'action': 'create_anonymous',
      },
    );

    if (response.status == 200 && response.data['success'] == true) {
      final sessionData = response.data['data'];
      // Note: The custom anonymous session does not return a JWT.
      // The frontend will need a way to store and use the custom session_id.
      // This is a significant change from JWT-based anonymous sessions.
      // For now, we can store it in secure storage.
      await CoreAuthService.AuthService.storeAuthData(
        accessToken: sessionData['session_id'], // Using session_id as the token
        userType: 'guest',
        userId: sessionData['session_id'],
      );
      return true;
    } else {
      throw Exception(response.data['message'] ?? 'Anonymous sign-in failed');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Anonymous Sign-In Error: $e');
    }
    rethrow;
  }
}
```

### 2.5. Submit Feedback

**Endpoint**: `POST /functions/v1/feedback`

-   **What Changed**: This is a new feature specified in the API. A service and corresponding BLoC events/states need to be created.
-   **Files to Update**: This will require new files.
    1.  `frontend/lib/features/feedback/data/services/feedback_service.dart` (new)
    2.  `frontend/lib/features/feedback/presentation/bloc/feedback_bloc.dart` (new)
-   **Action Required**: Implement a new service to call the `/feedback` endpoint. The `user_context` in the request body should be populated based on the user's authentication state.

**Example Implementation for `FeedbackService`:**
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/api_auth_helper.dart';

class FeedbackService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> submitFeedback({
    String? studyGuideId,
    required bool wasHelpful,
    String? message,
    String? category,
  }) async {
    final user = _supabase.auth.currentUser;
    final headers = await ApiAuthHelper.getAuthHeaders();

    final body = {
      'study_guide_id': studyGuideId,
      'was_helpful': wasHelpful,
      'message': message,
      'category': category,
      'user_context': {
        'is_authenticated': user != null && !user.isAnonymous,
        'user_id': user?.id,
        'session_id': await ApiAuthHelper.getAuthHeaders().then((h) => h['x-session-id']),
      }
    };

    final response = await _supabase.functions.invoke(
      'feedback',
      body: body,
      headers: headers,
    );

    if (response.status != 200) {
      throw Exception(response.data['message'] ?? 'Failed to submit feedback');
    }
  }
}
```

## 3. General Recommendations

-   **Update Error Handling**: Review all API service files and ensure that `catch` blocks are updated to parse the standardized error format: `{ "success": false, "error": "ERROR_CODE", "message": "..." }`.
-   **Dependency Injection**: Ensure all new or updated services are correctly registered in the dependency injection container (`frontend/lib/core/di/injection_container.dart`).
-   **Testing**: After making these changes, thoroughly test all related features:
    -   Study guide generation (anonymous and authenticated).
    -   Daily verse display and language switching.
    -   Fetching recommended topics.
    -   Anonymous and Google Sign-In flows.
    -   Saving and viewing study guides.
    -   Submitting feedback.

By following this guide, the frontend application will be successfully aligned with the latest backend API, ensuring more secure, robust, and consistent communication.