import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/utils/detect_study_input.dart';

void main() {
  final cases = <String, DetectedInputType>{
    'John 3:16': DetectedInputType.scripture,
    'Psalm 23': DetectedInputType.scripture,
    '1 Cor 13:4-7': DetectedInputType.scripture,
    'Romans 8': DetectedInputType.scripture,
    'romans 8': DetectedInputType.scripture,
    '1 Corinthians 10:23-11:1': DetectedInputType.scripture,
    '1 John 3': DetectedInputType.scripture,
    'रोमियों 8:28': DetectedInputType.scripture,
    'यूहन्ना 3:16': DetectedInputType.scripture,
    'റോമർ 8': DetectedInputType.scripture,
    'യോഹന്നാൻ 3:16': DetectedInputType.scripture,
    'What is the purpose of prayer?': DetectedInputType.question,
    'Why did Jesus die': DetectedInputType.question,
    'Why, Lord': DetectedInputType.question,
    'John 3:16?': DetectedInputType.question,
    'क्या परमेश्वर मुझसे प्रेम करता है': DetectedInputType.question,
    'എങ്ങനെ പ്രാർത്ഥിക്കണം': DetectedInputType.question,
    'ദൈവം സ്നേഹമാണോ?': DetectedInputType.question,
    'Grace': DetectedInputType.topic,
    'Forgiveness': DetectedInputType.topic,
    'John': DetectedInputType.topic,
    'Romans and grace 8': DetectedInputType.topic,
    'John 3:16 and grace': DetectedInputType.topic,
    'Isaiah': DetectedInputType.topic,
    'Whatever': DetectedInputType.topic,
    'Hope in suffering': DetectedInputType.topic,
    'प्रेम': DetectedInputType.topic,
    'John प्रेम': DetectedInputType.topic,
    '': DetectedInputType.topic,
    '   ': DetectedInputType.topic,
  };
  cases.forEach((input, type) {
    test('"$input" -> $type', () => expect(detectStudyInput(input).type, type));
  });

  test('validity', () {
    expect(detectStudyInput('a').isValid, isFalse);
    expect(detectStudyInput('Why?').isValid, isFalse);
    expect(detectStudyInput('').isValid, isFalse);
    expect(detectStudyInput('   ').isValid, isFalse);
    expect(detectStudyInput('Go').isValid, isTrue);
    expect(detectStudyInput('Why did Jesus die').isValid, isTrue);
    expect(detectStudyInput('John 3:16').isValid, isTrue);
    expect(detectStudyInput('John 3:1?').isValid, isFalse);
  });

  test('normalises whitespace', () {
    expect(detectStudyInput('  John   3:16 ').text, 'John 3:16');
    expect(detectStudyInput('John\t3:16\n').type, DetectedInputType.scripture);
  });

  test('apiValue', () {
    expect(DetectedInputType.scripture.apiValue, 'scripture');
    expect(DetectedInputType.topic.apiValue, 'topic');
    expect(DetectedInputType.question.apiValue, 'question');
  });
}
