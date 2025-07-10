# 📲 Saved Guides API Integration

## 🎯 Overview

This integration connects the Saved Guides screen with the new `/functions/v1/study-guides` API, providing real-time data fetching, pagination, and save/unsave functionality.

## 🏗️ Architecture

### New Components Created:

1. **`SavedGuidesApiBloc`** - Enhanced BLoC with API integration
2. **`SavedScreenApi`** - Updated screen with tab handling and pagination
3. **`GuideListItemApi`** - Enhanced list item with save/unsave actions
4. **`GuideShimmerItem`** - Shimmer loading placeholder
5. **`StudyGuidesApiService`** - API service for backend communication

## 🔧 Key Features Implemented

### ✅ Tab State Handling
- **Saved Tab**: Fetches with `?saved=true`
- **Recent Tab**: Fetches with `?saved=false`
- Debounced tab switching (300ms) to prevent excessive API calls
- State preservation during tab switches

### ✅ Pagination Support
- **Infinite Scroll**: Loads more data when scrolling near bottom (80% threshold)
- **Pull-to-Refresh**: Swipe down to refresh data
- **Offset Tracking**: Maintains separate pagination for saved and recent guides
- **hasMore Logic**: Prevents unnecessary API calls when no more data

### ✅ Response Parsing
- Extracts: `summary`, `input_value`, `language`, `is_saved`, `created_at`
- Converts API models to domain entities
- Formats content for display with markdown-style parsing

### ✅ Empty State UI
- **No Saved Guides**: Shows bookmark icon with helpful message
- **No Recent Guides**: Shows history icon with explanation
- **Custom Icons**: Different icons and messages per tab

### ✅ Error & Loading States
- **Shimmer Loading**: Animated placeholders during initial load
- **Bottom Loading**: Progress indicator for pagination
- **Error Handling**: Network errors, authentication issues, server problems
- **Retry Logic**: Retry button on error states

## 🚀 Usage Example

```dart
// Basic integration in router
BlocProvider(
  create: (context) => SavedGuidesApiBloc(
    apiService: StudyGuidesApiService(),
  )..add(const LoadSavedGuidesFromApi(refresh: true)),
  child: const SavedScreenApi(),
)

// Tab switching
context.read<SavedGuidesApiBloc>().add(
  TabChangedEvent(tabIndex: 0), // 0 = Saved, 1 = Recent
);

// Save/Unsave guide
context.read<SavedGuidesApiBloc>().add(
  ToggleGuideApiEvent(guideId: 'uuid', save: true),
);

// Load more data (pagination)
context.read<SavedGuidesApiBloc>().add(
  LoadSavedGuidesFromApi(offset: currentGuides.length),
);
```

## 📱 API Integration Details

### GET Requests
```dart
// Saved guides
final savedGuides = await apiService.getStudyGuides(
  savedOnly: true,
  limit: 20,
  offset: 0,
);

// Recent guides  
final recentGuides = await apiService.getStudyGuides(
  savedOnly: false,
  limit: 20,
  offset: 0,
);
```

### POST Requests (Save/Unsave)
```dart
final updatedGuide = await apiService.saveUnsaveGuide(
  guideId: 'uuid',
  save: true, // true = save, false = unsave
);
```

## 🎨 UI Components

### Enhanced Guide List Item
- **Save Button**: Bookmark icon for unsaved recent guides
- **Remove Option**: Menu for saved guides to remove from saved
- **Loading State**: Overlay with spinner during save/unsave operations
- **Visual Indicators**: Different icons and colors for saved vs unsaved

### Shimmer Loading
- **Animated Placeholders**: Smooth opacity animation
- **Proper Sizing**: Matches actual content dimensions
- **Performance**: Optimized single ticker animation

## 🔒 Authentication Requirements

- **Authenticated Users Only**: All API calls require valid auth token
- **Token Management**: Automatic token retrieval from secure storage
- **Fallback Headers**: Uses Supabase anon key as fallback
- **Error Handling**: Proper 401 unauthorized responses

## 📊 State Management

### BLoC States
```dart
// Loading state with tab information
SavedGuidesTabLoading(tabIndex: 0, isRefresh: true)

// Loaded state with pagination info
SavedGuidesApiLoaded(
  savedGuides: [...],
  recentGuides: [...],
  isLoadingSaved: false,
  isLoadingRecent: false,
  hasMoreSaved: true,
  hasMoreRecent: false,
  currentTab: 0,
)

// Error with retry option
SavedGuidesError(message: "Network error")

// Success action feedback
SavedGuidesActionSuccess(message: "Guide saved")
```

## 🚨 Error Handling

### Network Errors
- Connection timeouts
- Server unavailable
- Rate limiting

### Authentication Errors
- Token expiry
- Invalid credentials
- Unauthorized access

### Data Errors
- Invalid response format
- Missing required fields
- Malformed JSON

## 🎯 Performance Optimizations

1. **Debounced Tab Changes**: Prevents rapid API calls
2. **Efficient Pagination**: Only loads when needed
3. **State Preservation**: Maintains data during navigation
4. **Optimistic Updates**: Immediate UI feedback for save/unsave
5. **Memory Management**: Proper disposal of controllers and subscriptions

## 🔄 Integration Steps

1. **Replace Current Screen**: Use `SavedScreenApi` instead of `SavedScreen`
2. **Update Router**: Inject API service dependency
3. **Authentication Check**: Ensure user is authenticated before access
4. **Theme Integration**: Uses existing `AppTheme` constants
5. **Navigation**: Compatible with existing GoRouter setup

This integration provides a production-ready, API-connected saved guides experience with proper error handling, loading states, and smooth user interactions.