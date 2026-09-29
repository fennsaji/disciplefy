import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart'
    as auth_states;
import 'package:disciplefy_bible_study/features/onboarding/presentation/widgets/onboarding_previews.dart';
import 'package:disciplefy_bible_study/shared/widgets/welcome_chrome.dart';

/// Onboarding carousel: four feature slides, each with a live-widget app
/// preview, then login.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
  }

  /// Check if user is already authenticated and redirect if needed
  void _checkAuthenticationStatus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is auth_states.AuthenticatedState) {
        // User is already authenticated, redirect to home
        context.go('/');
      }
    });
  }

  static const List<_SlideSpec> _slides = [
    _SlideSpec(
      eyebrowKey: TranslationKeys.onboardingSlide1Eyebrow,
      titleKey: TranslationKeys.onboardingSlide1Title,
      descriptionKey: TranslationKeys.onboardingSlide1Description,
      verseKey: TranslationKeys.onboardingSlide1Verse,
      reference: 'Psalm 119:105',
      preview: DailyVersePreview(),
    ),
    _SlideSpec(
      eyebrowKey: TranslationKeys.onboardingSlide2Eyebrow,
      titleKey: TranslationKeys.onboardingSlide2Title,
      descriptionKey: TranslationKeys.onboardingSlide2Description,
      verseKey: TranslationKeys.onboardingSlide2Verse,
      reference: '2 Timothy 3:16',
      preview: StudyGuidePreview(),
    ),
    _SlideSpec(
      eyebrowKey: TranslationKeys.onboardingSlide3Eyebrow,
      titleKey: TranslationKeys.onboardingSlide3Title,
      descriptionKey: TranslationKeys.onboardingSlide3Description,
      verseKey: TranslationKeys.onboardingSlide3Verse,
      reference: 'Jeremiah 33:3',
      preview: DisciplerChatPreview(),
    ),
    _SlideSpec(
      eyebrowKey: TranslationKeys.onboardingSlide4Eyebrow,
      titleKey: TranslationKeys.onboardingSlide4Title,
      descriptionKey: TranslationKeys.onboardingSlide4Description,
      verseKey: TranslationKeys.onboardingSlide4Verse,
      reference: 'Psalm 119:11',
      preview: MemoryReviewPreview(),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _handleContinueButton() {
    if (_currentPage == _slides.length - 1) {
      // Last slide - complete onboarding and navigate to login
      _completeOnboarding();
    } else {
      // Not on last slide - go to next slide
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _completeOnboarding() async {
    // Mark onboarding as completed
    final box = Hive.box('app_settings');
    await box.put('onboarding_completed', true);

    // Set flag to auto-activate free plan after authentication
    await box.put('auto_activate_free_plan', true);

    if (mounted) {
      // Navigate directly to login instead of pricing page
      context.go(AppRoutes.login);
    }
  }

  void _skipOnboarding() async {
    // Mark onboarding as completed
    final box = Hive.box('app_settings');
    await box.put('onboarding_completed', true);

    // Set flag to auto-activate free plan after authentication
    await box.put('auto_activate_free_plan', true);

    if (mounted) {
      // Navigate directly to login instead of pricing page
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: palette.page,
      body: Stack(
        children: [
          const Positioned.fill(child: WelcomeGlow()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    // Brand row + Skip
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 12, 4),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: WelcomeBrandRow(),
                            ),
                          ),
                          TextButton(
                            key: const Key('onboarding_skip'),
                            onPressed: _skipOnboarding,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              foregroundColor: palette.muted,
                            ),
                            child: Text(
                              context.tr(TranslationKeys.onboardingSkipIntro),
                              style: AppFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: palette.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Slides
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        itemCount: _slides.length,
                        itemBuilder: (context, index) =>
                            _OnboardingSlideView(slide: _slides[index]),
                      ),
                    ),

                    // Dots + Continue
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                      child: Row(
                        children: [
                          _PageDots(
                            count: _slides.length,
                            current: _currentPage,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: WelcomePrimaryButton(
                                key: const Key('onboarding_continue'),
                                expand: false,
                                label: isLast
                                    ? context.tr(
                                        TranslationKeys.onboardingGetStarted)
                                    : context
                                        .tr(TranslationKeys.onboardingContinue),
                                onPressed: _handleContinueButton,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One onboarding slide: app preview, eyebrow, title, description, verse.
class _OnboardingSlideView extends StatelessWidget {
  final _SlideSpec slide;

  const _OnboardingSlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // The preview takes a share of the height and scales down to it, so
        // short screens keep the text in view.
        final previewHeight = (constraints.maxHeight * 0.5).clamp(120.0, 360.0);
        final isNarrow = constraints.maxWidth < 360;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                height: previewHeight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: slide.preview,
                ),
              ),
              SizedBox(height: isNarrow ? 18 : 24),
              WelcomeEyebrow(context.tr(slide.eyebrowKey)),
              const SizedBox(height: 10),
              WelcomeTitle(
                context.tr(slide.titleKey),
                fontSize: isNarrow ? 25 : 30,
              ),
              const SizedBox(height: 12),
              Text(
                context.tr(slide.descriptionKey),
                style: AppFonts.inter(
                  fontSize: isNarrow ? 14.5 : 15.5,
                  height: 1.55,
                  color: palette.muted,
                ),
              ),
              const SizedBox(height: 18),
              _VerseBlock(
                verse: context.tr(slide.verseKey),
                reference: slide.reference,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Italic verse with a gold left rule and gold reference.
class _VerseBlock extends StatelessWidget {
  final String verse;
  final String reference;

  const _VerseBlock({required this.verse, required this.reference});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      padding: const EdgeInsets.only(left: 14, top: 2, bottom: 2),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: palette.gold, width: 2.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\u201C$verse\u201D',
            style: AppFonts.inter(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.45,
              color: palette.text.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reference,
            style: AppFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.gold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Page dots: the active page is a wide gold pill.
class _PageDots extends StatelessWidget {
  final int count;
  final int current;

  const _PageDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Semantics(
      label: '${current + 1} / $count',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              margin: EdgeInsets.only(right: i == count - 1 ? 0 : 6),
              width: i == current ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == current
                    ? palette.gold
                    : palette.dim.withValues(alpha: palette.isDark ? 0.6 : 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

/// Content of one onboarding slide. Text is looked up by translation key;
/// scripture references stay as written.
class _SlideSpec {
  final String eyebrowKey;
  final String titleKey;
  final String descriptionKey;
  final String verseKey;
  final String reference;
  final Widget preview;

  const _SlideSpec({
    required this.eyebrowKey,
    required this.titleKey,
    required this.descriptionKey,
    required this.verseKey,
    required this.reference,
    required this.preview,
  });
}
