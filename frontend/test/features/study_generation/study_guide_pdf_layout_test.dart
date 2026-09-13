import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:disciplefy_bible_study/features/study_generation/data/services/study_guide_pdf_service.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_guide.dart';

/// Lays [guide] out exactly like the app's English PDF, with the bundled Inter
/// font so no network is needed.
Future<pw.Document> _buildPdf(StudyGuide guide) async {
  pw.Font font(String name) => pw.Font.ttf(
      File('assets/fonts/$name').readAsBytesSync().buffer.asByteData());
  final service = StudyGuidePdfService();
  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(
      base: font('Inter-Regular.ttf'),
      bold: font('Inter-Bold.ttf'),
      italic: font('Inter-Medium.ttf'),
    ),
  );
  pdf.addPage(
    pw.MultiPage(
      maxPages: 100,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (_) => service.buildTextPdfHeader(guide),
      footer: (ctx) => service.buildTextPdfFooter(ctx, guide),
      build: (_) => service.buildTextPdfContent(guide),
    ),
  );
  return pdf;
}

StudyGuide _guide({
  required String summary,
  required String interpretation,
  String context = 'Historical context.',
  String? passage,
  List<String> relatedVerses = const ['Psalm 19:1-4'],
  List<String> reflectionQuestions = const ['What does this show you?'],
  List<String> prayerPoints = const ['Thank God for His goodness.'],
}) =>
    StudyGuide(
      id: 'test',
      input: 'Does God Exist?',
      inputType: 'topic',
      summary: summary,
      interpretation: interpretation,
      context: context,
      passage: passage,
      relatedVerses: relatedVerses,
      reflectionQuestions: reflectionQuestions,
      prayerPoints: prayerPoints,
      language: 'en',
      createdAt: DateTime(2026, 9, 12),
    );

void main() {
  group('parseStudyGuideText', () {
    test('a **line** becomes a bold sub-heading without the markers', () {
      final blocks = parseStudyGuideText(
          "**Creation Declares God's Existence**\nWhen you look at the sky.");
      expect(blocks.length, 2);
      expect(blocks[0].isHeading, isTrue);
      expect(blocks[0].plainText, "Creation Declares God's Existence");
      expect(blocks[1].isHeading, isFalse);
      expect(blocks[1].plainText, 'When you look at the sky.');
    });

    test('inline **bold** stays bold and markers are removed', () {
      final block = parseStudyGuideText('God is **holy** and *good*.').single;
      expect(block.isHeading, isFalse);
      expect(block.plainText, 'God is holy and good.');
      expect(block.runs.where((r) => r.bold).map((r) => r.text), ['holy']);
    });

    test('a paragraph with two bold runs is not mistaken for a heading', () {
      final block =
          parseStudyGuideText('**Faith** and **works** together.').single;
      expect(block.isHeading, isFalse);
      expect(block.plainText, 'Faith and works together.');
    });

    test('markdown # headings and blank lines are handled', () {
      final blocks = parseStudyGuideText('## Grace\n\n\nSaved by grace.');
      expect(blocks.map((b) => b.isHeading), [true, false]);
      expect(blocks.first.plainText, 'Grace');
    });
  });

  test('every paragraph and list item can continue onto the next page', () {
    final guide = _guide(
      summary: 'Summary paragraph.',
      interpretation: '**Heading**\nFirst paragraph.\nSecond paragraph.',
    );
    final spanning = StudyGuidePdfService()
        .buildTextPdfContent(guide)
        .whereType<pw.Padding>()
        .where((w) => w.child is pw.RichText && w.child is! pw.Text)
        .toList();

    // 1 summary + 2 interpretation paragraphs + context + 3 list items.
    expect(spanning.length, 7);
    expect(spanning.every((w) => w.canSpan), isTrue,
        reason: 'a paragraph that cannot span is pushed whole to the next '
            'page, leaving the rest of the page blank');
  });

  test('long prose fills pages instead of leaving half of each one blank',
      () async {
    // ~9 pages of 950-character paragraphs. With paragraphs that could not
    // span, each page broke early and this needed noticeably more pages.
    const paragraph =
        'Paul writes that God has made Himself known through what '
        'He has made, so that His eternal power and divine nature are clearly '
        'seen. The universe did not create itself, and the design in nature did '
        'not happen by accident. The moral law written on every heart points to '
        'a holy Lawgiver who defines goodness by His very nature. Some people '
        'spend their lives running from this conclusion, but the evidence is '
        'there, and the question is whether we will honestly examine it and '
        'humble ourselves before the Creator who made us for relationship with '
        'Him. The same God who flung stars into space loves us personally and '
        'sent His Son to die for our sins, so that we might be reconciled to '
        'Him and live the life we were created for.';
    final interpretation = [
      for (var i = 0; i < 24; i++) ...[
        if (i % 4 == 0) '**Section ${i ~/ 4 + 1}**',
        paragraph,
      ],
    ].join('\n');

    final pdf = await _buildPdf(_guide(
      summary: paragraph,
      interpretation: interpretation,
      prayerPoints: [List.filled(4, paragraph).join(' ')],
    ));
    await pdf.save();

    expect(pdf.document.pdfPageList.pages.length, lessThanOrEqualTo(10));
  });

  test('renders the real guide to a PDF when PDF_FIXTURE is set', () async {
    final fixturePath = Platform.environment['PDF_FIXTURE'];
    final outPath = Platform.environment['PDF_OUT'];
    if (fixturePath == null || outPath == null) return;

    final fx = jsonDecode(File(fixturePath).readAsStringSync())
        as Map<String, dynamic>;
    final guide = _guide(
      summary: fx['summary'] as String,
      passage: fx['passage'] as String,
      interpretation: fx['interpretation'] as String,
      context: fx['context'] as String,
      relatedVerses: List<String>.from(fx['relatedVerses'] as List),
      reflectionQuestions: List<String>.from(fx['reflectionQuestions'] as List),
      prayerPoints: List<String>.from(fx['prayerPoints'] as List),
    );
    final pdf = await _buildPdf(guide);
    File(outPath).writeAsBytesSync(await pdf.save());
  });
}
