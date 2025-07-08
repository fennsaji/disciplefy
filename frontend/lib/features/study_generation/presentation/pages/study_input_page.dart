import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../bloc/study_bloc.dart';
import '../widgets/verse_input_widget.dart';
import '../widgets/topic_input_widget.dart';

class StudyInputPage extends StatefulWidget {
  const StudyInputPage({super.key});

  @override
  State<StudyInputPage> createState() => _StudyInputPageState();
}

class _StudyInputPageState extends State<StudyInputPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _verseController = TextEditingController();
  final _topicController = TextEditingController();
  String? _verseError;
  String? _topicError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _verseController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    // If localization is not ready, show loading
    if (l10n == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.studyInputTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.studyInputVerseTab),
            Tab(text: l10n.studyInputTopicTab),
          ],
        ),
      ),
      body: BlocListener<StudyBloc, StudyState>(
        listener: (context, state) {
          if (state is StudyGenerationSuccess) {
            context.go('/study-result', extra: state.studyGuide);
          } else if (state is StudyGenerationFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.failure.message),
                backgroundColor: Theme.of(context).colorScheme.error,
                action: state.isRetryable
                    ? SnackBarAction(
                        label: 'Retry',
                        onPressed: () {
                          // Retry the last operation
                          final inputType = _tabController.index == 0 ? 'scripture' : 'topic';
                          _generateStudyGuide(inputType);
                        },
                      )
                    : null,
              ),
            );
          }
        },
        child: BlocBuilder<StudyBloc, StudyState>(
          builder: (context, state) {
            return Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [
                    VerseInputWidget(
                      controller: _verseController,
                      error: _verseError,
                      onChanged: (value) => setState(() => _verseError = null),
                      onSubmit: () => _generateStudyGuide('verse'),
                    ),
                    TopicInputWidget(
                      controller: _topicController,
                      error: _topicError,
                      onChanged: (value) => setState(() => _topicError = null),
                      onSubmit: () => _generateStudyGuide('topic'),
                    ),
                  ],
                ),
                if (state is StudyGenerationInProgress)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                l10n.studyInputGenerating,
                                style: Theme.of(context).textTheme.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _generateStudyGuide(String inputType) {
    final input = inputType == 'verse' 
        ? _verseController.text.trim()
        : _topicController.text.trim();
    
    // Validate input
    if (inputType == 'verse') {
      final error = _validateVerse(input);
      if (error != null) {
        setState(() => _verseError = error);
        return;
      }
    } else {
      final error = _validateTopic(input);
      if (error != null) {
        setState(() => _topicError = error);
        return;
      }
    }

    // Generate study guide
    context.read<StudyBloc>().add(
      GenerateStudyGuideRequested(
        input: input,
        inputType: inputType,
      ),
    );
  }

  String? _validateVerse(String input) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return 'Validation not available';
    
    if (input.isEmpty) {
      return l10n.studyInputVerseValidation;
    }

    // Basic verse validation patterns
    final versePatterns = [
      RegExp(r'^\d*\s*\w+\s+\d{1,3}:\d{1,3}(-\d{1,3})?$'), // John 3:16-17
      RegExp(r'^\d*\s*\w+\s+\d{1,3}:\d{1,3}-\d{1,3}:\d{1,3}$'), // John 3:16-4:2
      RegExp(r'^\d*\s*\w+\s+\d{1,3}$'), // Psalm 23
    ];

    final isValid = versePatterns.any((pattern) => pattern.hasMatch(input));
    
    if (!isValid) {
      return l10n.studyInputVerseValidation;
    }

    return null;
  }

  String? _validateTopic(String input) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return 'Validation not available';
    
    if (input.isEmpty || input.length < 2 || input.length > 100) {
      return l10n.studyInputTopicValidation;
    }

    // Check for inappropriate content
    final forbiddenPatterns = [
      'script', 'javascript', 'eval', 'function',
      'admin', 'system', 'override', 'ignore'
    ];
    
    final lowerInput = input.toLowerCase();
    for (final pattern in forbiddenPatterns) {
      if (lowerInput.contains(pattern)) {
        return l10n.studyInputTopicValidation;
      }
    }

    return null;
  }
}