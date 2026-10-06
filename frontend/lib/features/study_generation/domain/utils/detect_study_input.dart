import 'package:disciplefy_bible_study/core/constants/bible_books.dart';

/// What the single Generate input was recognised as.
enum DetectedInputType {
  scripture,
  topic,
  question;

  String get apiValue => name;
}

class DetectedInput {
  final DetectedInputType type;
  final String text;
  final bool isValid;

  const DetectedInput(this.type, this.text, this.isValid);
}

const _minQuestionLength = 10;
const _minTopicLength = 2;

const _questionWords = <String>{
  // English
  'what', 'why', 'how', 'who', 'when', 'where', 'which', 'is', 'are', 'can',
  'does', 'do', 'did', 'should', 'will',
  // Hindi
  'क्या', 'क्यों', 'कैसे', 'कौन', 'कब', 'कहाँ',
  // Malayalam
  'എന്ത്', 'എന്തുകൊണ്ട്', 'എങ്ങനെ', 'ആര്', 'എപ്പോൾ', 'എവിടെ',
};

// Leading/trailing punctuation that may stick to the first word ("Why,").
final _edgePunctuation =
    RegExp(r'^[\p{P}\p{S}]+|[\p{P}\p{S}]+$', unicode: true);

// Book + chapter [+ verse, range, cross-chapter range], anchored to the whole
// input so "John 3:16 and grace" is not scripture. Built from the shared
// pattern so every supported language and abbreviation is recognised.
RegExp? _anchoredScripture;
String? _anchoredSource;

RegExp _scriptureOnly() {
  final source = BibleBooks.getScripturePattern();
  if (_anchoredScripture == null || _anchoredSource != source) {
    _anchoredSource = source;
    _anchoredScripture = RegExp(
      '^(?:$source)\$',
      unicode: true,
      caseSensitive: false,
    );
  }
  return _anchoredScripture!;
}

/// Classifies free text as a scripture reference, a question or a topic.
DetectedInput detectStudyInput(String raw) {
  final text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');

  if (text.isNotEmpty && _scriptureOnly().hasMatch(text)) {
    return DetectedInput(DetectedInputType.scripture, text, true);
  }

  final firstWord =
      text.split(' ').first.toLowerCase().replaceAll(_edgePunctuation, '');
  if (text.endsWith('?') ||
      text.endsWith('？') ||
      _questionWords.contains(firstWord)) {
    return DetectedInput(
      DetectedInputType.question,
      text,
      text.length >= _minQuestionLength,
    );
  }

  return DetectedInput(
    DetectedInputType.topic,
    text,
    text.length >= _minTopicLength,
  );
}
