import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart'
    show
        Widget,
        BuildContext,
        MediaQuery,
        Material,
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
        debugPrint,
        FocusManager,
        decodeImageFromList,
        View;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart'
    show BuildOwner, RenderObjectToWidgetAdapter, WidgetsBinding;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/i18n/app_translations.dart';
import '../../../../core/models/app_language.dart';
import '../../domain/entities/study_guide.dart';

/// Service for generating PDF documents from study guides.
///
/// Creates professional, print-friendly PDFs for sermon preparation
/// and personal study use.
///
/// For English text, uses native PDF text rendering.
/// For Hindi/Malayalam (complex scripts), uses image-based rendering
/// to ensure proper ligature and character display.
class StudyGuidePdfService {
  /// Checks if the language requires image-based rendering.
  ///
  /// Hindi and Malayalam require complex script rendering (GSUB/ligatures)
  /// which the dart_pdf package doesn't support natively.
  bool _requiresImageBasedRendering(String language) {
    final lang = language.toLowerCase();
    return lang == 'hi' || lang == 'ml';
  }

  /// Generates a PDF document from a study guide.
  ///
  /// Returns the PDF as bytes that can be shared, printed, or saved.
  /// For complex scripts (Hindi/Malayalam), uses image-based rendering.
  Future<Uint8List> generatePdf(StudyGuide guide,
      {BuildContext? context}) async {
    if (_requiresImageBasedRendering(guide.language) && context != null) {
      return _generateImageBasedPdf(guide, context);
    }
    return _generateTextBasedPdf(guide);
  }

  /// Generates a text-based PDF (for English and other Latin scripts).
  Future<Uint8List> _generateTextBasedPdf(StudyGuide guide) async {
    final theme = await _getThemeForLanguage(guide.language);
    final pdf = pw.Document(theme: theme);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(guide),
        footer: (context) => _buildFooter(context, guide),
        build: (context) => [
          _buildTitleSection(guide),
          pw.SizedBox(height: 20),
          _buildSection('Summary', guide.summary),
          _buildSection('Interpretation', guide.interpretation),
          _buildSection('Historical Context', guide.context),
          _buildListSection('Related Scriptures', guide.relatedVerses),
          _buildNumberedListSection(
              'Reflection Questions', guide.reflectionQuestions),
          _buildListSection('Prayer Points', guide.prayerPoints),
          if (guide.personalNotes != null && guide.personalNotes!.isNotEmpty)
            _buildSection('Personal Notes', guide.personalNotes!),
        ],
      ),
    );

    return pdf.save();
  }

  /// Generates an image-based PDF for complex scripts (Hindi/Malayalam).
  ///
  /// This approach captures Flutter widgets as images to preserve
  /// correct text rendering with ligatures and complex character combinations.
  Future<Uint8List> _generateImageBasedPdf(
      StudyGuide guide, BuildContext context) async {
    final pdf = pw.Document();

    // Capture each section as an image
    final List<Uint8List> sectionImages = [];

    // Helper to capture with proper frame scheduling to keep UI responsive
    Future<Uint8List?> captureWithYield(Widget widget) async {
      // Wait for end of current frame to allow animations to progress
      await WidgetsBinding.instance.endOfFrame;
      // Use lower pixel ratio (2.0 instead of 3.0) for faster capture
      // Still provides good quality for PDF
      final result = await _captureWidgetAsImage(widget, context,
          width: 515, pixelRatio: 2.0);
      // Wait for another frame to let UI catch up
      await WidgetsBinding.instance.endOfFrame;
      return result;
    }

    // Build and capture the header section
    final headerImage = await captureWithYield(_buildFlutterHeader(guide));
    if (headerImage != null) sectionImages.add(headerImage);

    // Build and capture the title section
    final titleImage = await captureWithYield(_buildFlutterTitleSection(guide));
    if (titleImage != null) sectionImages.add(titleImage);

    // Build and capture content sections
    final sections = [
      (_getLocalizedTitle('Summary', guide.language), guide.summary),
      (
        _getLocalizedTitle('Interpretation', guide.language),
        guide.interpretation
      ),
      (_getLocalizedTitle('Historical Context', guide.language), guide.context),
    ];

    for (final section in sections) {
      if (section.$2.isNotEmpty) {
        final image = await captureWithYield(
          _buildFlutterSection(section.$1, section.$2, guide.language),
        );
        if (image != null) sectionImages.add(image);
      }
    }

    // Related verses
    if (guide.relatedVerses.isNotEmpty) {
      final image = await captureWithYield(
        _buildFlutterListSection(
            _getLocalizedTitle('Related Scriptures', guide.language),
            guide.relatedVerses,
            guide.language),
      );
      if (image != null) sectionImages.add(image);
    }

    // Reflection questions
    if (guide.reflectionQuestions.isNotEmpty) {
      final image = await captureWithYield(
        _buildFlutterNumberedListSection(
            _getLocalizedTitle('Reflection Questions', guide.language),
            guide.reflectionQuestions,
            guide.language),
      );
      if (image != null) sectionImages.add(image);
    }

    // Prayer points
    if (guide.prayerPoints.isNotEmpty) {
      final image = await captureWithYield(
        _buildFlutterListSection(
            _getLocalizedTitle('Prayer Points', guide.language),
            guide.prayerPoints,
            guide.language),
      );
      if (image != null) sectionImages.add(image);
    }

    // Personal notes
    if (guide.personalNotes != null && guide.personalNotes!.isNotEmpty) {
      final image = await captureWithYield(
        _buildFlutterSection(
            _getLocalizedTitle('Personal Notes', guide.language),
            guide.personalNotes!,
            guide.language),
      );
      if (image != null) sectionImages.add(image);
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
            child: Material(
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
      debugPrint('Error capturing widget as image: $e');
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

  Widget _buildFlutterTitleSection(StudyGuide guide) {
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
            style: _getFontForLanguage(guide.language)(
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
          style: AppFonts.inter(fontSize: 10, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: AppFonts.inter(
            fontSize: 10,
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
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: _getFontForLanguage(language)(
              fontSize: 11,
              color: Colors.grey[900],
              height: 1.5,
            ),
            textAlign: TextAlign.justify,
          ),
        ],
      ),
    );
  }

  Widget _buildFlutterListSection(
      String title, List<String> items, String language) {
    if (items.isEmpty) return const SizedBox.shrink();

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
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                          fontSize: 11,
                          color: Colors.grey[900],
                          height: 1.4,
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
      String title, List<String> items, String language) {
    if (items.isEmpty) return const SizedBox.shrink();

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
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...items.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 20,
                      child: Text(
                        '${entry.key + 1}.',
                        style: AppFonts.inter(
                          fontSize: 11,
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
                          fontSize: 11,
                          color: Colors.grey[900],
                          height: 1.4,
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
            'www.disciplefy.in',
            style: AppFonts.inter(fontSize: 9, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// Gets the appropriate font function for the language.
  TextStyle Function({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    FontStyle? fontStyle,
    double? letterSpacing,
  }) _getFontForLanguage(String language) {
    // AppFonts.inter works well for all languages in Flutter's text rendering
    // as Flutter handles complex scripts correctly
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

  /// Shares the PDF using the system share sheet.
  Future<void> sharePdf(StudyGuide guide, {BuildContext? context}) async {
    final pdfBytes = await generatePdf(guide, context: context);
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
            'www.disciplefy.in',
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
            fontSize: 10,
            color: PdfColors.grey600,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
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

  /// Builds a standard text section with a heading.
  pw.Widget _buildSection(String title, String content) {
    if (content.isEmpty) return pw.SizedBox.shrink();

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: PdfColors.grey300,
                ),
              ),
            ),
            child: pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
                letterSpacing: 1,
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            content,
            style: const pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey900,
              lineSpacing: 4,
            ),
            textAlign: pw.TextAlign.justify,
          ),
        ],
      ),
    );
  }

  /// Builds a bulleted list section.
  pw.Widget _buildListSection(String title, List<String> items) {
    if (items.isEmpty) return pw.SizedBox.shrink();

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: PdfColors.grey300,
                ),
              ),
            ),
            child: pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
                letterSpacing: 1,
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          ...items.map((item) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 6,
                      height: 6,
                      margin: const pw.EdgeInsets.only(top: 4, right: 10),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey600,
                        shape: pw.BoxShape.circle,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        item,
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey900,
                          lineSpacing: 3,
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

  /// Builds a numbered list section.
  pw.Widget _buildNumberedListSection(String title, List<String> items) {
    if (items.isEmpty) return pw.SizedBox.shrink();

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: PdfColors.grey300,
                ),
              ),
            ),
            child: pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
                letterSpacing: 1,
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          ...items.asMap().entries.map((entry) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 20,
                      margin: const pw.EdgeInsets.only(right: 8),
                      child: pw.Text(
                        '${entry.key + 1}.',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        entry.value,
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey900,
                          lineSpacing: 3,
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
}
