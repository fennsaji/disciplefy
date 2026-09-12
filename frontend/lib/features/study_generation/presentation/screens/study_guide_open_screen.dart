import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_routes.dart';
import '../../../saved_guides/data/services/study_guides_api_service.dart';
import '../pages/study_guide_screen_v2.dart';

/// Resolves a shared study-guide link (`/study-guide/:guideId`) into the
/// actual guide screen.
///
/// This route sits behind the app's global auth redirect, so an
/// unauthenticated visitor is already sent through login (and back here)
/// before this screen ever builds — by the time it runs, fetching the guide
/// only needs to handle "not found or not owned", which the API reports as a
/// 404 rather than a generic error.
class StudyGuideOpenScreen extends StatefulWidget {
  final String guideId;
  const StudyGuideOpenScreen({super.key, required this.guideId});

  @override
  State<StudyGuideOpenScreen> createState() => _StudyGuideOpenScreenState();
}

class _StudyGuideOpenScreenState extends State<StudyGuideOpenScreen> {
  Map<String, dynamic>? _guide;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<String, dynamic>? guide;
    try {
      guide =
          await sl<StudyGuidesApiService>().getStudyGuideById(widget.guideId);
    } catch (_) {
      guide = null;
    }

    if (!mounted) return;

    if (guide == null) {
      context.go(AppRoutes.home);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content:
                Text(context.tr(TranslationKeys.studyGuideLinkUnavailable)),
            behavior: SnackBarBehavior.floating,
          ));
      });
      return;
    }

    setState(() {
      _guide = guide;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _guide == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StudyGuideScreenV2(
      input: _guide!['verse_reference'] ??
          _guide!['topic_name'] ??
          _guide!['title'],
      type: _guide!['type'],
      language: _guide!['language'] ?? 'en',
      existingGuideData: _guide,
    );
  }
}
