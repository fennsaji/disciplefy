import '../entities/memory_verse_entity.dart';
import '../entities/review_statistics_entity.dart';
import '../repositories/memory_verse_repository.dart';

/// Returns locally-cached due verses without any network call.
///
/// Used for stale-while-revalidate: call this first to show data immediately,
/// then call [GetDueVerses] in background to refresh from remote.
/// Returns null when no local cache exists yet.
class GetCachedDueVerses {
  final MemoryVerseRepository repository;

  GetCachedDueVerses(this.repository);

  Future<(List<MemoryVerseEntity>, ReviewStatisticsEntity)?> call({
    String? language,
  }) {
    return repository.getCachedDueVerses(language: language);
  }
}
