import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'dart:ui' as ui;
import 'package:flutter/material.dart' as material;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart'
    show
        Widget,
        BuildContext,
        MediaQuery,
        Colors,
        SizedBox,
        Container,
        EdgeInsets,
        BoxDecoration,
        Border,
        BorderSide,
        Row,
        MainAxisAlignment,
        Text,
        Column,
        CrossAxisAlignment,
        Padding,
        Expanded,
        BoxShape,
        BorderRadius,
        FontWeight,
        FontStyle,
        MainAxisSize,
        FocusManager,
        decodeImageFromList,
        View;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart'
    show BuildOwner, ColoredBox, RenderObjectToWidgetAdapter, WidgetsBinding;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/i18n/app_translations.dart';
import '../../../../core/models/app_language.dart';
import '../../domain/entities/study_guide.dart';
import '../../../../core/utils/logger.dart';

/// A run of text inside a [PdfTextBlock]; [bold] when it came from `**…**`.
@visibleForTesting
class PdfTextRun {
  final String text;
  final bool bold;
  const PdfTextRun(this.text, {this.bold = false});
}

/// One block of study-guide prose laid out in the PDF: either a sub-heading
/// line (`**Creation Declares God's Existence**`) or a paragraph whose inline
/// `**bold**` runs stay bold. The markers themselves are never printed.
@visibleForTesting
class PdfTextBlock {
  final bool isHeading;
  final List<PdfTextRun> runs;
  const PdfTextBlock({required this.isHeading, required this.runs});

  String get plainText => runs.map((r) => r.text).join();
}

final _pdfHeadingLine = RegExp(r'^(?:#{1,6}\s*)?\*\*([^*]+)\*\*:?$');
final _pdfHashHeading = RegExp(r'^#{1,6}\s+(.+)$');
final _pdfBoldRun = RegExp(r'\*\*([^*]+)\*\*');
final _pdfItalic = RegExp(r'(?<![*\w])\*(?!\s)([^*\n]+?)(?<!\s)\*(?![*\w])');

String _stripPdfItalic(String s) =>
    s.replaceAllMapped(_pdfItalic, (m) => m.group(1)!);

/// Splits generated study-guide text into headings and paragraphs, turning
/// markdown emphasis into bold runs instead of literal asterisks.
@visibleForTesting
List<PdfTextBlock> parseStudyGuideText(String text) {
  final blocks = <PdfTextBlock>[];
  for (final raw in text.split(RegExp(r'\n+'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;

    final heading =
        _pdfHeadingLine.firstMatch(line) ?? _pdfHashHeading.firstMatch(line);
    if (heading != null) {
      final title =
          _stripPdfItalic(heading.group(1)!.replaceAll('**', '').trim());
      blocks.add(PdfTextBlock(
        isHeading: true,
        runs: [PdfTextRun(title, bold: true)],
      ));
      continue;
    }

    final runs = <PdfTextRun>[];
    var last = 0;
    for (final m in _pdfBoldRun.allMatches(line)) {
      if (m.start > last) {
        runs.add(PdfTextRun(_stripPdfItalic(line.substring(last, m.start))));
      }
      runs.add(PdfTextRun(_stripPdfItalic(m.group(1)!), bold: true));
      last = m.end;
    }
    if (last < line.length) {
      runs.add(PdfTextRun(_stripPdfItalic(line.substring(last))));
    }
    blocks.add(PdfTextBlock(isHeading: false, runs: runs));
  }
  return blocks;
}

/// Service for generating PDF documents from study guides.
///
/// Creates professional, print-friendly PDFs for sermon preparation
/// and personal study use.
///
/// For English text, uses native PDF text rendering.
/// For Hindi/Malayalam (complex scripts), uses image-based rendering
/// to ensure proper ligature and character display.
class StudyGuidePdfService {
  /// Returns 'hi', 'ml', or null by scanning [text] for Devanagari / Malayalam
  /// Unicode blocks (U+0900–U+097F and U+0D00–U+0D7F respectively).
  String? _detectComplexScript(String text) {
    for (final rune in text.runes.take(500)) {
      if (rune >= 0x0900 && rune <= 0x097F) return 'hi'; // Devanagari
      if (rune >= 0x0D00 && rune <= 0x0D7F) return 'ml'; // Malayalam
    }
    return null;
  }

  /// Checks if the guide requires image-based rendering.
  ///
  /// Returns true when:
  /// • `guide.language` is explicitly 'hi' or 'ml', OR
  /// • the title/summary contains Devanagari or Malayalam characters
  ///   (handles guides where the language field is mis-set to 'en' but the
  ///   LLM produced content in a complex script).
  bool _requiresImageBasedRendering(StudyGuide guide) {
    final lang = guide.language.toLowerCase();
    if (lang == 'hi' || lang == 'ml') return true;
    return _detectComplexScript('${guide.title} ${guide.summary}') != null;
  }

  /// Generates a PDF document from a study guide.
  ///
  /// Returns the PDF as bytes that can be shared, printed, or saved.
  /// For complex scripts (Hindi/Malayalam), uses image-based rendering.
  ///
  /// [onProgress] is called after each named section is captured, with
  /// (currentStep, totalSteps). Useful for showing progress in the UI.
  Future<Uint8List> generatePdf(
    StudyGuide guide, {
    BuildContext? context,
    void Function(int step, int total)? onProgress,
  }) async {
    if (_requiresImageBasedRendering(guide) && context != null) {
      return _generateImageBasedPdf(guide, context, onProgress: onProgress);
    }
    return _generateTextBasedPdf(guide, onProgress: onProgress);
  }

  /// Generates a text-based PDF (for English and other Latin scripts).
  ///
  /// Runs PDF construction in a background isolate to avoid blocking the
  /// main thread. Falls back to main-thread execution if the isolate fails
  /// (e.g. on platforms where isolates are unsupported or restricted).
  Future<Uint8List> _generateTextBasedPdf(
    StudyGuide guide, {
    void Function(int step, int total)? onProgress,
  }) async {
    // dart:isolate is unsupported on Flutter Web — skip directly to main thread.
    if (kIsWeb) {
      return _buildTextPdfOnCurrentThread(guide, onProgress: onProgress);
    }

    final guideData = _studyGuideToMap(guide);
    try {
      // Signal "building" phase — isolate is doing the heavy work.
      onProgress?.call(0, 1);
      final bytes = await Isolate.run(() => _buildTextPdfInIsolate(guideData));
      // Signal finalizing phase — browser download is about to be triggered.
      onProgress?.call(1, 1);
      return bytes;
    } catch (e) {
      Logger.warning(
          '[StudyGuidePdfService] Isolate PDF failed, using main thread: $e');
      return _buildTextPdfOnCurrentThread(guide, onProgress: onProgress);
    }
  }

  /// Builds the text-based PDF on the current (main) thread.
  ///
  /// Used as a fallback when the isolate-based path fails.
  Future<Uint8List> _buildTextPdfOnCurrentThread(
    StudyGuide guide, {
    void Function(int step, int total)? onProgress,
  }) async {
    final theme = await _getThemeForLanguage(guide.language);
    final pdf = pw.Document(theme: theme);

    pdf.addPage(
      pw.MultiPage(
        maxPages: 100,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (_) => _buildHeader(guide),
        footer: (ctx) => _buildFooter(ctx, guide),
        build: (_) => buildTextPdfContent(guide),
      ),
    );

    // Signal finalizing phase before the (potentially slow) pdf.save() call.
    onProgress?.call(1, 1);
    return pdf.save();
  }

  /// Session cache: tracks which complex-script fonts have been downloaded and
  /// registered with CanvasKit this session so we don't wait again.
  static final Set<String> _webFontsLoaded = {};

  /// Pre-loads the Google Font for complex scripts on Flutter Web.
  ///
  /// Calls `GoogleFonts.notoSansDevanagari()` / `notoSansMalayalam()`, which
  /// downloads the font from CDN and registers it with Flutter's `FontLoader`.
  /// Once `FontLoader.load()` completes, `PaintingBinding` fires
  /// `systemFonts.notifyListeners()`. We await that notification (max 8 s)
  /// so CanvasKit has the typeface before the off-screen widget captures begin.
  Future<void> _preloadWebFont(String language) async {
    if (!kIsWeb) return;
    final lang = language.toLowerCase();
    if (lang != 'hi' && lang != 'ml') return;
    if (_webFontsLoaded.contains(lang)) return; // already loaded this session

    final completer = Completer<void>();
    void onFontsChanged() {
      if (!completer.isCompleted) completer.complete();
    }

    // systemFonts is on PaintingBinding (mixed into WidgetsBinding); it
    // notifies listeners whenever FontLoader.load() finishes.
    PaintingBinding.instance.systemFonts.addListener(onFontsChanged);

    // Trigger the CDN download + FontLoader.load()
    if (lang == 'hi') {
      GoogleFonts.notoSansDevanagari();
    } else {
      GoogleFonts.notoSansMalayalam();
    }

    // Wait for font registration or timeout
    await Future.any([
      completer.future,
      Future.delayed(const Duration(seconds: 8)),
    ]);

    PaintingBinding.instance.systemFonts.removeListener(onFontsChanged);
    _webFontsLoaded.add(lang);

    // One extra frame so CanvasKit can process the newly registered typeface
    await WidgetsBinding.instance.endOfFrame;
  }

  /// Generates an image-based PDF for complex scripts (Hindi/Malayalam).
  ///
  /// This approach captures Flutter widgets as images to preserve
  /// correct text rendering with ligatures and complex character combinations.
  Future<Uint8List> _generateImageBasedPdf(
    StudyGuide guide,
    BuildContext context, {
    void Function(int step, int total)? onProgress,
  }) async {
    // Determine the effective script language.
    // Guides with language='en' but Devanagari/Malayalam content still need
    // the correct Noto font — scan title+summary to detect actual script.
    final effectiveLanguage =
        _detectComplexScript('${guide.title} ${guide.summary}') ??
            guide.language.toLowerCase();

    // Ensure the script-specific Google Font is registered with CanvasKit
    // before any off-screen widget captures happen.
    await _preloadWebFont(effectiveLanguage);

    final pdf = pw.Document();

    // Capture each section as an image
    final List<Uint8List> sectionImages = [];

    // Count named sections upfront so we can report progress accurately.
    // Chunks (paragraph splits within a section) don't count as separate steps.
    final contentSections = [
      (_getLocalizedTitle('Summary', effectiveLanguage), guide.summary),
      if (guide.passage != null && guide.passage!.isNotEmpty)
        (_getLocalizedTitle('Passage', effectiveLanguage), guide.passage!),
      (
        _getLocalizedTitle('Interpretation', effectiveLanguage),
        guide.interpretation
      ),
      (
        _getLocalizedTitle('Historical Context', effectiveLanguage),
        guide.context
      ),
    ];
    final totalSteps = 2 // header + title
        +
        contentSections.where((s) => s.$2.isNotEmpty).length +
        (guide.relatedVerses.isNotEmpty ? 1 : 0) +
        (guide.reflectionQuestions.isNotEmpty ? 1 : 0) +
        (guide.prayerPoints.isNotEmpty ? 1 : 0) +
        (guide.personalNotes?.isNotEmpty == true ? 1 : 0);
    int step = 0;

    // Yields to the event loop so the UI can update between heavy captures.
    // Reports progress for named sections (not for continuation chunks).
    Future<Uint8List?> captureSection(Widget widget) async {
      await WidgetsBinding.instance.endOfFrame;
      final result = await _captureWidgetAsImage(widget, context,
          width: 515, pixelRatio: 2.0);
      step++;
      onProgress?.call(step, totalSteps);
      await WidgetsBinding.instance.endOfFrame;
      return result;
    }

    // Continuation chunks within a section — no progress tick.
    Future<Uint8List?> captureChunk(Widget widget) async {
      await WidgetsBinding.instance.endOfFrame;
      final result = await _captureWidgetAsImage(widget, context,
          width: 515, pixelRatio: 2.0);
      await WidgetsBinding.instance.endOfFrame;
      return result;
    }

    // Build and capture the header section
    final headerImage = await captureSection(_buildFlutterHeader(guide));
    if (headerImage != null) sectionImages.add(headerImage);

    // Build and capture the title section
    final titleImage = await captureSection(
        _buildFlutterTitleSection(guide, effectiveLanguage));
    if (titleImage != null) sectionImages.add(titleImage);

    for (final section in contentSections) {
      if (section.$2.isEmpty) continue;
      // Split long content into paragraph-level chunks so that smaller images
      // can fill pages more efficiently (avoids large blank gaps when a single
      // tall image doesn't fit in the remaining page space).
      final chunks =
          _mergeHeadingChunks(_splitContentForPdf(section.$2, maxChars: 500));
      // First chunk gets the section heading + counts as one progress step
      final firstImage = await captureSection(
        _buildFlutterSection(section.$1, chunks.first, effectiveLanguage),
      );
      if (firstImage != null) sectionImages.add(firstImage);
      // Continuation chunks: plain text, no heading, no progress tick
      for (int i = 1; i < chunks.length; i++) {
        final chunkImage = await captureChunk(
          _buildFlutterTextChunk(chunks[i], effectiveLanguage),
        );
        if (chunkImage != null) sectionImages.add(chunkImage);
      }
    }

    // Lists: the heading is captured with the first item, then one image per
    // item, so a long list fills the page instead of moving as one block.
    Future<void> captureList(
        String titleKey, List<String> items, bool numbered) async {
      if (items.isEmpty) return;
      final title = _getLocalizedTitle(titleKey, effectiveLanguage);
      for (var i = 0; i < items.length; i++) {
        final widget = numbered
            ? _buildFlutterNumberedListSection(
                title, [items[i]], effectiveLanguage,
                showHeading: i == 0, startNumber: i + 1)
            : _buildFlutterListSection(title, [items[i]], effectiveLanguage,
                showHeading: i == 0);
        final image =
            i == 0 ? await captureSection(widget) : await captureChunk(widget);
        if (image != null) sectionImages.add(image);
      }
    }

    await captureList('Related Scriptures', guide.relatedVerses, false);
    await captureList('Reflection Questions', guide.reflectionQuestions, true);
    await captureList('Prayer Points', guide.prayerPoints, false);

    // Personal notes
    if (guide.personalNotes != null && guide.personalNotes!.isNotEmpty) {
      final chunks = _mergeHeadingChunks(
          _splitContentForPdf(guide.personalNotes!, maxChars: 500));
      final firstImage = await captureSection(
        _buildFlutterSection(
            _getLocalizedTitle('Personal Notes', effectiveLanguage),
            chunks.first,
            effectiveLanguage),
      );
      if (firstImage != null) sectionImages.add(firstImage);
      for (int i = 1; i < chunks.length; i++) {
        final chunkImage = await captureChunk(
          _buildFlutterTextChunk(chunks[i], effectiveLanguage),
        );
        if (chunkImage != null) sectionImages.add(chunkImage);
      }
    }

    // Build PDF pages from images
    // Calculate how many images fit per page
    double currentPageHeight = 0;
    const maxPageHeight = 760.0; // A4 height minus margins
    List<pw.Widget> currentPageWidgets = [];
    final List<List<pw.Widget>> allPages = []; // Store completed pages

    for (final imageBytes in sectionImages) {
      final image = pw.MemoryImage(imageBytes);

      // Estimate image height (we'll use a ratio based on A4 width)
      final decodedImage = await decodeImageFromList(imageBytes);
      final aspectRatio = decodedImage.width / decodedImage.height;
      final imageHeight = 515 / aspectRatio;

      if (currentPageHeight + imageHeight > maxPageHeight &&
          currentPageWidgets.isNotEmpty) {
        // Save current page and start a new one
        allPages.add(List.from(currentPageWidgets)); // Create a copy
        currentPageWidgets = [];
        currentPageHeight = 0;
      }

      currentPageWidgets.add(pw.Image(image, width: 515));
      currentPageWidgets.add(pw.SizedBox(height: 10));
      currentPageHeight += imageHeight + 10;
    }

    // Add all completed pages to PDF
    for (final pageWidgets in allPages) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: pageWidgets,
          ),
        ),
      );
    }

    // Add remaining widgets to last page with footer
    if (currentPageWidgets.isNotEmpty) {
      final footerImage = await _captureWidgetAsImage(
        _buildFlutterFooter(guide),
        context,
        width: 515,
      );

      final lastPageWidgets = List<pw.Widget>.from(currentPageWidgets);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              ...lastPageWidgets,
              pw.Spacer(),
              if (footerImage != null)
                pw.Image(pw.MemoryImage(footerImage), width: 515),
            ],
          ),
        ),
      );
    }

    return pdf.save();
  }

  /// Captures a Flutter widget as a PNG image.
  Future<Uint8List?> _captureWidgetAsImage(
    Widget widget,
    BuildContext context, {
    double width = 400,
    double pixelRatio = 3.0,
  }) async {
    try {
      final repaintBoundary = RenderRepaintBoundary();
      final view = View.of(context);

      final renderView = RenderView(
        view: view,
        child: RenderPositionedBox(
          child: repaintBoundary,
        ),
        configuration: ViewConfiguration(
          logicalConstraints: BoxConstraints(maxWidth: width),
          devicePixelRatio: pixelRatio,
        ),
      );

      final pipelineOwner = PipelineOwner();
      pipelineOwner.rootNode = renderView;
      renderView.prepareInitialFrame();

      final buildOwner = BuildOwner(focusManager: FocusManager());
      final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
        container: repaintBoundary,
        child: MediaQuery(
          data: MediaQuery.of(context),
          child: material.Directionality(
            textDirection: material.TextDirection.ltr,
            // Use ColoredBox instead of Material to avoid registering
            // MouseTrackerAnnotations in the off-screen pipeline owner,
            // which causes mouse_tracker.dart assertion failures on Flutter Web.
            child: ColoredBox(
              color: Colors.white,
              child: SizedBox(
                width: width,
                child: widget,
              ),
            ),
          ),
        ),
      ).attachToRenderTree(buildOwner);

      buildOwner.buildScope(rootElement);
      pipelineOwner.flushLayout();
      pipelineOwner.flushCompositingBits();
      pipelineOwner.flushPaint();

      final ui.Image image =
          await repaintBoundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      buildOwner.finalizeTree();

      return byteData?.buffer.asUint8List();
    } catch (e) {
      Logger.debug('Error capturing widget as image: $e');
      return null;
    }
  }

  // ============ Flutter Widget Builders (for image capture) ============

  Widget _buildFlutterHeader(StudyGuide guide) {
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'DISCIPLEFY',
            style: AppFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
              letterSpacing: 2,
            ),
          ),
          Text(
            'Bible Study Guide',
            style: AppFonts.inter(
              fontSize: 10,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlutterTitleSection(StudyGuide guide, String effectiveLanguage) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            guide.title,
            style: _getFontForLanguage(effectiveLanguage)(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildFlutterMetadataChip('Type',
                  guide.inputType == 'scripture' ? 'Scripture' : 'Topic'),
              const SizedBox(width: 16),
              _buildFlutterMetadataChip(
                  'Language', _getLanguageName(guide.language)),
              const SizedBox(width: 16),
              _buildFlutterMetadataChip(
                  'Reading Time', '~${guide.estimatedReadingTimeMinutes} min'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlutterMetadataChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: AppFonts.inter(fontSize: 11, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: AppFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildFlutterSection(String title, String content, String language) {
    if (content.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
            ),
            child: Text(
              title.toUpperCase(),
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildFlutterRichText(content, language),
        ],
      ),
    );
  }

  /// Flutter rendering of [parseStudyGuideText] blocks for image capture:
  /// sub-heading lines in bold, inline `**bold**` kept bold, no raw markers.
  Widget _buildFlutterRichText(String content, String language) {
    final base = _getFontForLanguage(language)(
      fontSize: 13,
      color: Colors.grey[900],
      height: 1.6,
    );
    const bold = TextStyle(fontWeight: FontWeight.bold);
    final blocks = parseStudyGuideText(content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks)
          Padding(
            padding: EdgeInsets.only(top: block.isHeading ? 4 : 0, bottom: 6),
            child: Text.rich(
              TextSpan(
                style: base,
                children: [
                  for (final run in block.runs)
                    TextSpan(
                      text: run.text,
                      style: run.bold || block.isHeading ? bold : null,
                    ),
                ],
              ),
              textAlign: block.isHeading ? TextAlign.start : TextAlign.justify,
            ),
          ),
      ],
    );
  }

  /// Keeps a lone sub-heading chunk together with the paragraph after it, so a
  /// heading image never ends a page with its text on the next one.
  static List<String> _mergeHeadingChunks(List<String> chunks) {
    final merged = <String>[];
    for (final chunk in chunks) {
      if (merged.isNotEmpty && _pdfHeadingLine.hasMatch(merged.last.trim())) {
        merged[merged.length - 1] = '${merged.last}\n$chunk';
      } else {
        merged.add(chunk);
      }
    }
    return merged;
  }

  /// Renders a plain block of text with no section heading.
  /// Used for continuation chunks of long sections so page breaks happen
  /// at paragraph boundaries rather than forcing the whole section to a new page.
  Widget _buildFlutterTextChunk(String content, String language) {
    if (content.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      child: _buildFlutterRichText(content, language),
    );
  }

  Widget _buildFlutterListSection(
      String title, List<String> items, String language,
      {bool showHeading = true}) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(top: showHeading ? 15 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeading) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
              ),
              child: Text(
                title.toUpperCase(),
                style: AppFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 6, right: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: _getFontForLanguage(language)(
                          fontSize: 13,
                          color: Colors.grey[900],
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFlutterNumberedListSection(
      String title, List<String> items, String language,
      {bool showHeading = true, int startNumber = 1}) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(top: showHeading ? 15 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeading) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
              ),
              child: Text(
                title.toUpperCase(),
                style: AppFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ...items.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        '${entry.key + startNumber}.',
                        style: AppFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: _getFontForLanguage(language)(
                          fontSize: 13,
                          color: Colors.grey[900],
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFlutterFooter(StudyGuide guide) {
    final dateFormat = DateFormat('MMMM d, yyyy');
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Generated: ${dateFormat.format(guide.createdAt)}',
            style: AppFonts.inter(fontSize: 9, color: Colors.grey[500]),
          ),
          Text(
            'app.disciplefy.in',
            style: AppFonts.inter(fontSize: 9, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// Gets the appropriate font function for the language.
  ///
  /// For Hindi and Malayalam, returns a Google Fonts function that uses
  /// Noto Sans scripts — these are fetched from Google CDN and registered
  /// with Flutter's CanvasKit font manager, ensuring Devanagari / Malayalam
  /// glyphs render correctly in off-screen PDF captures on Flutter Web.
  TextStyle Function({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    FontStyle? fontStyle,
    double? letterSpacing,
  }) _getFontForLanguage(String language) {
    final lang = language.toLowerCase();
    if (lang == 'hi') {
      return ({
        double? fontSize,
        FontWeight? fontWeight,
        Color? color,
        double? height,
        FontStyle? fontStyle,
        double? letterSpacing,
      }) =>
          GoogleFonts.notoSansDevanagari(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
            height: height,
            fontStyle: fontStyle,
            letterSpacing: letterSpacing,
          );
    } else if (lang == 'ml') {
      return ({
        double? fontSize,
        FontWeight? fontWeight,
        Color? color,
        double? height,
        FontStyle? fontStyle,
        double? letterSpacing,
      }) =>
          GoogleFonts.notoSansMalayalam(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
            height: height,
            fontStyle: fontStyle,
            letterSpacing: letterSpacing,
          );
    }
    return AppFonts.inter;
  }

  // ============ PDF Widget Builders (for text-based PDF) ============

  /// Gets the appropriate fonts based on the study guide language.
  Future<pw.ThemeData> _getThemeForLanguage(String language) async {
    // For text-based PDF, we use Inter for English
    // Hindi/Malayalam use image-based rendering instead
    return pw.ThemeData.withFont(
      base: await PdfGoogleFonts.interRegular(),
      bold: await PdfGoogleFonts.interBold(),
      italic: await PdfGoogleFonts.interMedium(),
    );
  }

  /// Converts [StudyGuide] to a primitive map safe for isolate transfer.
  ///
  /// Only includes fields required for PDF rendering; complex objects like
  /// [TokenConsumption] are intentionally omitted.
  Map<String, dynamic> _studyGuideToMap(StudyGuide guide) => {
        'id': guide.id,
        'input': guide.input,
        'inputType': guide.inputType,
        'summary': guide.summary,
        'interpretation': guide.interpretation,
        'context': guide.context,
        'passage': guide.passage,
        'relatedVerses': List<String>.from(guide.relatedVerses),
        'reflectionQuestions': List<String>.from(guide.reflectionQuestions),
        'prayerPoints': List<String>.from(guide.prayerPoints),
        'language': guide.language,
        'createdAt': guide.createdAt.millisecondsSinceEpoch,
        'personalNotes': guide.personalNotes,
      };

  /// Reconstructs a minimal [StudyGuide] from a primitive map (used inside
  /// the background isolate — only PDF-relevant fields are populated).
  static StudyGuide _mapToStudyGuide(Map<String, dynamic> data) => StudyGuide(
        id: data['id'] as String,
        input: data['input'] as String,
        inputType: data['inputType'] as String,
        summary: data['summary'] as String,
        interpretation: data['interpretation'] as String,
        context: data['context'] as String,
        passage: data['passage'] as String?,
        relatedVerses: List<String>.from(data['relatedVerses'] as List),
        reflectionQuestions:
            List<String>.from(data['reflectionQuestions'] as List),
        prayerPoints: List<String>.from(data['prayerPoints'] as List),
        language: data['language'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int),
        personalNotes: data['personalNotes'] as String?,
      );

  /// Builds the full PDF inside a background isolate.
  ///
  /// Creates a fresh [StudyGuidePdfService] and [StudyGuide] instance from
  /// the serialized [data] map so no non-transferable objects are captured
  /// across the isolate boundary.
  static Future<Uint8List> _buildTextPdfInIsolate(
      Map<String, dynamic> data) async {
    final guide = _mapToStudyGuide(data);
    final service = StudyGuidePdfService();

    final theme = pw.ThemeData.withFont(
      base: await PdfGoogleFonts.interRegular(),
      bold: await PdfGoogleFonts.interBold(),
      italic: await PdfGoogleFonts.interMedium(),
    );
    final pdf = pw.Document(theme: theme);

    pdf.addPage(
      pw.MultiPage(
        maxPages: 100,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (_) => service._buildHeader(guide),
        footer: (ctx) => service._buildFooter(ctx, guide),
        build: (_) => service.buildTextPdfContent(guide),
      ),
    );

    return pdf.save();
  }

  /// Shares the PDF using the system share sheet.
  Future<void> sharePdf(
    StudyGuide guide, {
    BuildContext? context,
    void Function(int step, int total)? onProgress,
  }) async {
    final pdfBytes =
        await generatePdf(guide, context: context, onProgress: onProgress);
    final fileName = _generateFileName(guide);

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: fileName,
    );
  }

  /// Generates a filename for the PDF based on the study guide.
  String _generateFileName(StudyGuide guide) {
    final sanitizedInput = guide.input
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    final truncated = sanitizedInput.length > 30
        ? sanitizedInput.substring(0, 30)
        : sanitizedInput;
    return 'disciplefy_study_$truncated.pdf';
  }

  /// Builds the header for each page.
  pw.Widget _buildHeader(StudyGuide guide) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColors.grey400,
            width: 0.5,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'DISCIPLEFY',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
              letterSpacing: 2,
            ),
          ),
          pw.Text(
            'Bible Study Guide',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey500,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the footer for each page.
  pw.Widget _buildFooter(pw.Context context, StudyGuide guide) {
    final dateFormat = DateFormat('MMMM d, yyyy');
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color: PdfColors.grey400,
            width: 0.5,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated: ${dateFormat.format(guide.createdAt)}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey500,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey500,
            ),
          ),
          pw.Text(
            'app.disciplefy.in',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey500,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the title section with the study guide title and metadata.
  pw.Widget _buildTitleSection(StudyGuide guide) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            guide.title,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _buildMetadataChip('Type',
                  guide.inputType == 'scripture' ? 'Scripture' : 'Topic'),
              pw.SizedBox(width: 16),
              _buildMetadataChip('Language', _getLanguageName(guide.language)),
              pw.SizedBox(width: 16),
              _buildMetadataChip(
                  'Reading Time', '~${guide.estimatedReadingTimeMinutes} min'),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a small metadata chip.
  pw.Widget _buildMetadataChip(String label, String value) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          '$label: ',
          style: const pw.TextStyle(
            fontSize: 11,
            color: PdfColors.grey600,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
      ],
    );
  }

  /// Converts language code to display name.
  String _getLanguageName(String code) {
    switch (code.toLowerCase()) {
      case 'en':
        return 'English';
      case 'hi':
        return 'Hindi';
      case 'ml':
        return 'Malayalam';
      default:
        return code.toUpperCase();
    }
  }

  /// Gets localized section title based on language using AppTranslations.
  String _getLocalizedTitle(String sectionKey, String language) {
    final appLanguage = _getAppLanguage(language);
    final translations = AppTranslations.translations[appLanguage];

    if (translations == null) return sectionKey;

    // Navigate to study_guide.sections
    final studyGuide = translations['study_guide'] as Map<String, dynamic>?;
    if (studyGuide == null) return sectionKey;

    final sections = studyGuide['sections'] as Map<String, dynamic>?;
    if (sections == null) return sectionKey;

    // Map English titles to translation keys
    const titleToKey = {
      'Summary': 'summary',
      'Passage': 'passage_reading',
      'Interpretation': 'interpretation',
      'Historical Context': 'context',
      'Related Scriptures': 'related_verses',
      'Reflection Questions': 'discussion_questions',
      'Prayer Points': 'prayer_points',
      'Personal Notes': 'personal_notes',
    };

    final key = titleToKey[sectionKey];
    if (key == null) return sectionKey;

    return sections[key] as String? ?? sectionKey;
  }

  /// Converts language code to AppLanguage enum.
  AppLanguage _getAppLanguage(String code) {
    switch (code.toLowerCase()) {
      case 'hi':
        return AppLanguage.hindi;
      case 'ml':
        return AppLanguage.malayalam;
      default:
        return AppLanguage.english;
    }
  }

  // ─── Section builder helpers ─────────────────────────────────────────────

  /// Splits [text] into page-safe chunks so no single [pw.Text] widget
  /// exceeds page height and triggers [TooManyPagesException].
  ///
  /// Strategy:
  ///   1. Split on newline boundaries (paragraphs).
  ///   2. For paragraphs longer than [maxChars], split further at sentence
  ///      endings (.  !  ?) to stay under the limit.
  static List<String> _splitContentForPdf(String text, {int maxChars = 800}) {
    if (text.isEmpty) return [];

    final result = <String>[];

    for (final paragraph in text.split(RegExp(r'\n+'))) {
      final trimmed = paragraph.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.length <= maxChars) {
        result.add(trimmed);
      } else {
        var chunk = '';
        for (final sentence in trimmed.split(RegExp(r'(?<=[.!?])\s+'))) {
          if (chunk.length + sentence.length > maxChars && chunk.isNotEmpty) {
            result.add(chunk.trim());
            chunk = sentence;
          } else {
            chunk += (chunk.isEmpty ? '' : ' ') + sentence;
          }
        }
        if (chunk.isNotEmpty) result.add(chunk.trim());
      }
    }

    return result.isEmpty ? [text.trim()] : result;
  }

  /// Builds a bordered section heading widget (shared by all section builders).
  pw.Widget _buildSectionHeading(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300),
        ),
      ),
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey800,
          letterSpacing: 1,
        ),
      ),
    );
  }

  /// Builds a standard text section as a **flat list** of widgets.
  ///
  /// Each paragraph is its own [pw.RichText] with [pw.TextOverflow.span], so
  /// [pw.MultiPage] can continue it on the next page. Without `span` a
  /// paragraph that did not fit the space left was pushed whole to the next
  /// page, leaving the rest of the current page blank.
  List<pw.Widget> _buildSection(String title, String content) {
    if (content.trim().isEmpty) return [];

    return [
      _buildSectionHeading(title),
      ...parseStudyGuideText(content).map(_buildPdfBlock),
      pw.SizedBox(height: 14),
    ];
  }

  static const _pdfBodyStyle = pw.TextStyle(
    fontSize: 13,
    color: PdfColors.grey900,
    lineSpacing: 5,
  );

  static final _pdfBold = pw.TextStyle(fontWeight: pw.FontWeight.bold);

  pw.Widget _buildPdfBlock(PdfTextBlock block) {
    if (block.isHeading) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6, bottom: 4),
        child: pw.Text(
          block.plainText,
          style: pw.TextStyle(
            fontSize: 13.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey900,
          ),
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.RichText(
        text: pw.TextSpan(
          style: _pdfBodyStyle,
          children: [
            for (final run in block.runs)
              pw.TextSpan(text: run.text, style: run.bold ? _pdfBold : null),
          ],
        ),
        textAlign: pw.TextAlign.justify,
        overflow: pw.TextOverflow.span,
      ),
    );
  }

  /// One list entry as a single page-spanning text run with an inline marker.
  /// A [pw.Row] (the previous bullet layout) can never break across pages, so a
  /// long prayer point used to jump to a new page on its own.
  pw.Widget _buildPdfListItem(String marker, String item) {
    final runs = <PdfTextRun>[];
    for (final block in parseStudyGuideText(item)) {
      if (runs.isNotEmpty) runs.add(const PdfTextRun(' '));
      runs.addAll(block.isHeading
          ? [PdfTextRun(block.plainText, bold: true)]
          : block.runs);
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.RichText(
        text: pw.TextSpan(
          style: const pw.TextStyle(
            fontSize: 13,
            color: PdfColors.grey900,
            lineSpacing: 4,
          ),
          children: [
            pw.TextSpan(
              text: '$marker  ',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
            for (final run in runs)
              pw.TextSpan(text: run.text, style: run.bold ? _pdfBold : null),
          ],
        ),
        overflow: pw.TextOverflow.span,
      ),
    );
  }

  /// Builds a bulleted list section as a **flat list** of page-spanning items.
  List<pw.Widget> _buildListSection(String title, List<String> items) {
    if (items.isEmpty) return [];

    return [
      _buildSectionHeading(title),
      for (final item in items) _buildPdfListItem('•', item),
      pw.SizedBox(height: 14),
    ];
  }

  /// Builds a numbered list section as a **flat list** of page-spanning items.
  List<pw.Widget> _buildNumberedListSection(String title, List<String> items) {
    if (items.isEmpty) return [];

    return [
      _buildSectionHeading(title),
      for (var i = 0; i < items.length; i++)
        _buildPdfListItem('${i + 1}.', items[i]),
      pw.SizedBox(height: 14),
    ];
  }

  /// Text-path widgets for [guide], in page order. Exposed so tests can lay
  /// the guide out with the default font and check how it paginates.
  @visibleForTesting
  List<pw.Widget> buildTextPdfContent(StudyGuide guide) => [
        _buildTitleSection(guide),
        pw.SizedBox(height: 20),
        ..._buildSection('Summary', guide.summary),
        if (guide.passage != null && guide.passage!.isNotEmpty)
          ..._buildSection('Passage', guide.passage!),
        ..._buildSection('Interpretation', guide.interpretation),
        ..._buildSection('Historical Context', guide.context),
        ..._buildListSection('Related Scriptures', guide.relatedVerses),
        ..._buildNumberedListSection(
            'Reflection Questions', guide.reflectionQuestions),
        ..._buildListSection('Prayer Points', guide.prayerPoints),
        if (guide.personalNotes != null && guide.personalNotes!.isNotEmpty)
          ..._buildSection('Personal Notes', guide.personalNotes!),
      ];

  @visibleForTesting
  pw.Widget buildTextPdfHeader(StudyGuide guide) => _buildHeader(guide);

  @visibleForTesting
  pw.Widget buildTextPdfFooter(pw.Context context, StudyGuide guide) =>
      _buildFooter(context, guide);
}
