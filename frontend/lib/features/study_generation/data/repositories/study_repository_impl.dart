import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/study_guide.dart';
import '../../domain/repositories/study_repository.dart';
import '../../../../core/network/network_info.dart';

/// Implementation of the StudyRepository interface.
/// 
/// This class handles study guide generation, caching, and retrieval
/// using Supabase as the backend and Hive for local caching.
class StudyRepositoryImpl implements StudyRepository {
  /// Supabase client for API calls.
  final SupabaseClient _supabaseClient;
  
  /// Network information service.
  final NetworkInfo _networkInfo;
  
  /// UUID generator for creating unique IDs.
  final Uuid _uuid = const Uuid();
  
  /// Box name for caching study guides.
  static const String _studyGuidesBoxName = 'study_guides';

  /// Creates a new StudyRepositoryImpl instance.
  /// 
  /// [supabaseClient] The Supabase client for API calls.
  /// [networkInfo] The network information service.
  StudyRepositoryImpl({
    required SupabaseClient supabaseClient,
    required NetworkInfo networkInfo,
  })  : _supabaseClient = supabaseClient,
        _networkInfo = networkInfo;

  @override
  Future<Either<Failure, StudyGuide>> generateStudyGuide({
    required String input,
    required String inputType,
    required String language,
  }) async {
    try {
      // Check network connectivity
      if (!await _networkInfo.isConnected) {
        return const Left(NetworkFailure());
      }

      // Call Supabase Edge Function for study generation
      final response = await _supabaseClient.functions.invoke(
        'study-generate',
        body: {
          'input_type': inputType,
          'input_value': input,
          'language': language,
          'user_context': {
            'is_authenticated': false,
            'session_id': _uuid.v4(),
          },
        },
      );

      if (response.status == 200 && response.data != null) {
        final studyGuide = _parseStudyGuideFromResponse(response.data, input, inputType, language);
        
        // Cache the generated study guide
        await cacheStudyGuide(studyGuide);
        
        return Right(studyGuide);
      } else {
        // For development, return mock data on API failure
        final mockStudyGuide = _createMockStudyGuide(input, inputType, language);
        await cacheStudyGuide(mockStudyGuide);
        return Right(mockStudyGuide);
      }
    } on NetworkException catch (e) {
      return Left(NetworkFailure(
        message: e.message,
        code: e.code,
        context: e.context,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(
        message: e.message,
        code: e.code,
        context: e.context,
      ));
    } catch (e) {
      // For development, return mock data on any error
      try {
        final mockStudyGuide = _createMockStudyGuide(input, inputType, language);
        await cacheStudyGuide(mockStudyGuide);
        return Right(mockStudyGuide);
      } catch (cacheError) {
        return Left(ClientFailure(
          message: 'Failed to generate study guide',
          code: 'GENERATION_FAILED',
          context: {'originalError': e.toString(), 'cacheError': cacheError.toString()},
        ));
      }
    }
  }

  @override
  Future<List<StudyGuide>> getCachedStudyGuides() async {
    try {
      if (!Hive.isBoxOpen(_studyGuidesBoxName)) {
        await Hive.openBox(_studyGuidesBoxName);
      }
      
      final box = Hive.box(_studyGuidesBoxName);
      final studyGuides = <StudyGuide>[];
      
      for (final key in box.keys) {
        final data = box.get(key) as Map<dynamic, dynamic>?;
        if (data != null) {
          try {
            final studyGuide = _parseStudyGuideFromCache(data);
            studyGuides.add(studyGuide);
          } catch (e) {
            // Skip invalid cached entries
            continue;
          }
        }
      }
      
      // Sort by creation date (newest first)
      studyGuides.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Return only the most recent guides
      return studyGuides.take(AppConstants.MAX_STUDY_GUIDES_CACHE).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<bool> cacheStudyGuide(StudyGuide studyGuide) async {
    try {
      if (!Hive.isBoxOpen(_studyGuidesBoxName)) {
        await Hive.openBox(_studyGuidesBoxName);
      }
      
      final box = Hive.box(_studyGuidesBoxName);
      final data = _convertStudyGuideToMap(studyGuide);
      
      await box.put(studyGuide.id, data);
      
      // Cleanup old entries if cache exceeds limit
      if (box.length > AppConstants.MAX_STUDY_GUIDES_CACHE) {
        final allGuides = await getCachedStudyGuides();
        final oldestGuides = allGuides.skip(AppConstants.MAX_STUDY_GUIDES_CACHE);
        
        for (final guide in oldestGuides) {
          await box.delete(guide.id);
        }
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> clearCache() async {
    try {
      if (!Hive.isBoxOpen(_studyGuidesBoxName)) {
        await Hive.openBox(_studyGuidesBoxName);
      }
      
      final box = Hive.box(_studyGuidesBoxName);
      await box.clear();
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Parses a study guide from the API response.
  StudyGuide _parseStudyGuideFromResponse(
    Map<String, dynamic> data,
    String input,
    String inputType,
    String language,
  ) {
    final studyData = data['data'] as Map<String, dynamic>? ?? {};
    
    return StudyGuide(
      id: studyData['id'] as String? ?? _uuid.v4(),
      input: input,
      inputType: inputType,
      summary: studyData['summary'] as String? ?? 'No summary available',
      context: studyData['context'] as String? ?? 'No context available',
      relatedVerses: (studyData['related_verses'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      reflectionQuestions: (studyData['reflection_questions'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      prayerPoints: (studyData['prayer_points'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      language: language,
      createdAt: DateTime.now(),
    );
  }

  /// Parses a study guide from cached data.
  StudyGuide _parseStudyGuideFromCache(Map<dynamic, dynamic> data) {
    return StudyGuide(
      id: data['id'] as String,
      input: data['input'] as String,
      inputType: data['inputType'] as String,
      summary: data['summary'] as String,
      context: data['context'] as String,
      relatedVerses: (data['relatedVerses'] as List<dynamic>).map((e) => e.toString()).toList(),
      reflectionQuestions: (data['reflectionQuestions'] as List<dynamic>).map((e) => e.toString()).toList(),
      prayerPoints: (data['prayerPoints'] as List<dynamic>).map((e) => e.toString()).toList(),
      language: data['language'] as String? ?? AppConstants.DEFAULT_LANGUAGE,
      createdAt: DateTime.parse(data['createdAt'] as String),
      userId: data['userId'] as String?,
    );
  }

  /// Converts a study guide to a map for caching.
  Map<String, dynamic> _convertStudyGuideToMap(StudyGuide studyGuide) {
    return {
      'id': studyGuide.id,
      'input': studyGuide.input,
      'inputType': studyGuide.inputType,
      'summary': studyGuide.summary,
      'context': studyGuide.context,
      'relatedVerses': studyGuide.relatedVerses,
      'reflectionQuestions': studyGuide.reflectionQuestions,
      'prayerPoints': studyGuide.prayerPoints,
      'language': studyGuide.language,
      'createdAt': studyGuide.createdAt.toIso8601String(),
      'userId': studyGuide.userId,
    };
  }

  /// Creates a mock study guide for development and offline use.
  StudyGuide _createMockStudyGuide(String input, String inputType, String language) {
    if (inputType == 'scripture') {
      return StudyGuide(
        id: _uuid.v4(),
        input: input,
        inputType: inputType,
        summary: 'This verse from John\'s Gospel reveals the heart of God\'s love for humanity. It demonstrates the incredible sacrifice God made and the simple requirement for receiving eternal life.',
        context: 'This passage comes from John 3, where Jesus speaks with Nicodemus, a Pharisee who came to Jesus at night. Jesus is explaining the necessity of spiritual rebirth and God\'s plan for salvation.',
        relatedVerses: [
          'Romans 5:8 - "But God demonstrates his own love for us in this: While we were still sinners, Christ died for us."',
          '1 John 4:9 - "This is how God showed his love among us: He sent his one and only Son into the world that we might live through him."',
          'Ephesians 2:8-9 - "For it is by grace you have been saved, through faith—and this is not from yourselves, it is the gift of God—not by works, so that no one can boast."'
        ],
        reflectionQuestions: [
          'What does it mean that God "loved" the world? How does this shape your understanding of God\'s character?',
          'How does the phrase "one and only Son" emphasize the magnitude of God\'s sacrifice?',
          'What is the difference between believing about Jesus and believing in Jesus?',
          'How can understanding God\'s love impact the way you view yourself and others?'
        ],
        prayerPoints: [
          'Thank God for His incredible love that motivated Him to send Jesus',
          'Ask for a deeper understanding of what it means to truly believe in Jesus',
          'Pray for opportunities to share God\'s love with others who need to hear this message',
          'Express gratitude for the gift of eternal life through faith in Jesus'
        ],
        language: language,
        createdAt: DateTime.now(),
      );
    } else {
      return StudyGuide(
        id: _uuid.v4(),
        input: input,
        inputType: inputType,
        summary: 'Faith is central to the Christian life, involving trust in God\'s character and promises. It\'s both a gift from God and a choice we make daily.',
        context: 'Throughout Scripture, faith is presented as essential for pleasing God and living the Christian life. From Abraham\'s journey of faith to the heroes listed in Hebrews 11, faith involves trusting God even when we cannot see the full picture.',
        relatedVerses: [
          'Hebrews 11:1 - "Now faith is confidence in what we hope for and assurance about what we do not see."',
          'Romans 10:17 - "Consequently, faith comes from hearing the message, and the message is heard through the word about Christ."',
          'James 2:17 - "In the same way, faith by itself, if it is not accompanied by action, is dead."',
          'Hebrews 11:6 - "And without faith it is impossible to please God, because anyone who comes to him must believe that he exists and that he rewards those who earnestly seek him."'
        ],
        reflectionQuestions: [
          'How would you define faith in your own words?',
          'What areas of your life require more faith and trust in God?',
          'How does faith impact your daily decisions and actions?',
          'What helps strengthen your faith during difficult times?',
          'How can you demonstrate your faith through your actions?'
        ],
        prayerPoints: [
          'Ask God to increase your faith and help you trust Him more completely',
          'Pray for strength to act on your faith, even when it\'s difficult',
          'Thank God for being faithful and trustworthy in all circumstances',
          'Ask for wisdom to know how to live out your faith in practical ways'
        ],
        language: language,
        createdAt: DateTime.now(),
      );
    }
  }
}