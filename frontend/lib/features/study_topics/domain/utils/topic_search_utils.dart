import '../../../home/domain/entities/recommended_guide_topic.dart';

/// Utility class for search operations on study topics.
class TopicSearchUtils {
  /// Applies search filtering to a list of recommended guide topics.
  ///
  /// Performs case-insensitive search across topic title, description,
  /// category, and tags. Returns the original list if search query is empty.
  ///
  /// [topics] - The list of topics to filter
  /// [searchQuery] - The search term to filter by
  ///
  /// Returns filtered list of topics matching the search criteria.
  static List<RecommendedGuideTopic> applySearchFilter(
    List<RecommendedGuideTopic> topics,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) {
      return topics;
    }

    final query = searchQuery.toLowerCase();
    return topics.where((topic) {
      return topic.title.toLowerCase().contains(query) ||
          topic.description.toLowerCase().contains(query) ||
          topic.category.toLowerCase().contains(query) ||
          topic.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }
}
