import 'dart:async';
import 'package:hive/hive.dart';
import '../../../../core/error/exceptions.dart';
import '../models/saved_guide_model.dart';

abstract class SavedGuidesLocalDataSource {
  Future<List<SavedGuideModel>> getSavedGuides();
  Future<List<SavedGuideModel>> getRecentGuides();
  Future<void> saveGuide(SavedGuideModel guide);
  Future<void> removeGuide(String guideId);
  Future<void> addToRecent(SavedGuideModel guide);
  Future<void> clearAllSaved();
  Future<void> clearAllRecent();
  Stream<List<SavedGuideModel>> watchSavedGuides();
  Stream<List<SavedGuideModel>> watchRecentGuides();
}

class SavedGuidesLocalDataSourceImpl implements SavedGuidesLocalDataSource {
  static const String _savedGuidesBoxName = 'saved_guides';
  static const String _recentGuidesBoxName = 'recent_guides';
  static const int _maxRecentGuides = 10;

  final StreamController<List<SavedGuideModel>> _savedGuidesController = 
      StreamController<List<SavedGuideModel>>.broadcast();
  final StreamController<List<SavedGuideModel>> _recentGuidesController = 
      StreamController<List<SavedGuideModel>>.broadcast();

  Box<SavedGuideModel>? _savedGuidesBox;
  Box<SavedGuideModel>? _recentGuidesBox;

  Future<Box<SavedGuideModel>> get savedGuidesBox async {
    _savedGuidesBox ??= await Hive.openBox<SavedGuideModel>(_savedGuidesBoxName);
    return _savedGuidesBox!;
  }

  Future<Box<SavedGuideModel>> get recentGuidesBox async {
    _recentGuidesBox ??= await Hive.openBox<SavedGuideModel>(_recentGuidesBoxName);
    return _recentGuidesBox!;
  }

  @override
  Future<List<SavedGuideModel>> getSavedGuides() async {
    try {
      final box = await savedGuidesBox;
      final guides = box.values
          .where((guide) => guide.isSaved)
          .toList()
        ..sort((a, b) => b.lastAccessedAt.compareTo(a.lastAccessedAt));
      return guides;
    } catch (e) {
      throw CacheException(message: 'Failed to get saved guides: $e');
    }
  }

  @override
  Future<List<SavedGuideModel>> getRecentGuides() async {
    try {
      final box = await recentGuidesBox;
      final guides = box.values.toList()
        ..sort((a, b) => b.lastAccessedAt.compareTo(a.lastAccessedAt));
      return guides.take(_maxRecentGuides).toList();
    } catch (e) {
      throw CacheException(message: 'Failed to get recent guides: $e');
    }
  }

  @override
  Future<void> saveGuide(SavedGuideModel guide) async {
    try {
      final box = await savedGuidesBox;
      final savedGuide = guide.copyWith(
        isSaved: true,
        lastAccessedAt: DateTime.now(),
      );
      await box.put(guide.id, savedGuide);
      _emitSavedGuides();
    } catch (e) {
      throw CacheException(message: 'Failed to save guide: $e');
    }
  }

  @override
  Future<void> removeGuide(String guideId) async {
    try {
      final savedBox = await savedGuidesBox;
      final recentBox = await recentGuidesBox;
      
      await savedBox.delete(guideId);
      await recentBox.delete(guideId);
      
      _emitSavedGuides();
      _emitRecentGuides();
    } catch (e) {
      throw CacheException(message: 'Failed to remove guide: $e');
    }
  }

  @override
  Future<void> addToRecent(SavedGuideModel guide) async {
    try {
      final box = await recentGuidesBox;
      final recentGuide = guide.copyWith(
        isSaved: false,
        lastAccessedAt: DateTime.now(),
      );
      
      await box.put(guide.id, recentGuide);
      
      // Keep only the most recent guides
      if (box.length > _maxRecentGuides) {
        final guides = box.values.toList()
          ..sort((a, b) => b.lastAccessedAt.compareTo(a.lastAccessedAt));
        
        // Remove oldest guides
        for (int i = _maxRecentGuides; i < guides.length; i++) {
          await box.delete(guides[i].id);
        }
      }
      
      _emitRecentGuides();
    } catch (e) {
      throw CacheException(message: 'Failed to add to recent: $e');
    }
  }

  @override
  Future<void> clearAllSaved() async {
    try {
      final box = await savedGuidesBox;
      await box.clear();
      _emitSavedGuides();
    } catch (e) {
      throw CacheException(message: 'Failed to clear saved guides: $e');
    }
  }

  @override
  Future<void> clearAllRecent() async {
    try {
      final box = await recentGuidesBox;
      await box.clear();
      _emitRecentGuides();
    } catch (e) {
      throw CacheException(message: 'Failed to clear recent guides: $e');
    }
  }

  @override
  Stream<List<SavedGuideModel>> watchSavedGuides() {
    _emitSavedGuides();
    return _savedGuidesController.stream;
  }

  @override
  Stream<List<SavedGuideModel>> watchRecentGuides() {
    _emitRecentGuides();
    return _recentGuidesController.stream;
  }

  Future<void> _emitSavedGuides() async {
    try {
      final guides = await getSavedGuides();
      _savedGuidesController.add(guides);
    } catch (e) {
      _savedGuidesController.addError(e);
    }
  }

  Future<void> _emitRecentGuides() async {
    try {
      final guides = await getRecentGuides();
      _recentGuidesController.add(guides);
    } catch (e) {
      _recentGuidesController.addError(e);
    }
  }

  void dispose() {
    _savedGuidesController.close();
    _recentGuidesController.close();
  }
}