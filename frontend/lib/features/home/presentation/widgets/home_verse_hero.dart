import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_bloc.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_event.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_state.dart';
import '../../../daily_verse/presentation/widgets/daily_verse_actions.dart';

/// Scenery behind the home hero. One is picked per calendar day so the page
/// changes with the verse but stays put through the day.
const List<String> homeHeroImages = [
  'assets/images/hero/mountains_fog.jpg',
  'assets/images/hero/mountains_dawn.jpg',
];

/// The hero image for [date]: stable within a day, rotates across days.
String homeHeroImageFor(DateTime date) {
  final dayIndex =
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay;
  return homeHeroImages[dayIndex % homeHeroImages.length];
}

/// Translation key for the time-of-day greeting at [hour] (0–23).
String homeGreetingKeyFor(int hour) {
  if (hour >= 5 && hour < 12) return TranslationKeys.homeGoodMorning;
  if (hour >= 12 && hour < 17) return TranslationKeys.homeGoodAfternoon;
  return TranslationKeys.homeGoodEvening;
}

/// Verse size steps down with length so a long passage still fits the hero
/// without pushing the rest of home below the fold.
double homeVerseFontSize(String verseText) {
  final length = verseText.trim().length;
  if (length <= 60) return 27;
  if (length <= 120) return 22;
  return 18;
}

/// Past this many lines the verse is clamped; "Study now" opens it in full.
const int homeVerseMaxLines = 8;

/// Text on the scene is always light: the shade keeps the photo dark behind
/// it in both app themes.
const Color _onScene = Color(0xFFF2F2F4);
const Color _onSceneMuted = Color(0xFFD6D6DC);

/// Height of the strip at the hero's bottom edge that fades into the page.
const double _groundFadeHeight = 28;

/// Full-bleed top of the home screen: scenery photo, a greeting and the
/// verse of the day, with room at the top for the pinned header.
///
/// The photo fades into the page ground at the bottom (black in dark mode,
/// the warm off-white in light), and is shaded darkest at the very top so
/// the gold wordmark and header controls read on any photo.
class HomeVerseHero extends StatelessWidget {
  final String greeting;
  final String subtitle;
  final Widget verse;
  final String imageAsset;

  const HomeVerseHero({
    super.key,
    required this.greeting,
    required this.subtitle,
    required this.verse,
    required this.imageAsset,
  });

  @override
  Widget build(BuildContext context) {
    final ground = Theme.of(context).scaffoldBackgroundColor;
    final topInset = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRect(
            child: LayoutBuilder(
              builder: (context, box) {
                // Decode only as many pixels as are shown. The photos are
                // 3:2 and the hero is taller than that, so "cover" fills
                // the height: decode width = height x 1.5 (plus the parallax
                // zoom), never the full 1080px source on a small phone.
                final dpr = MediaQuery.devicePixelRatioOf(context);
                final coverWidth = box.maxWidth > box.maxHeight * 1.5
                    ? box.maxWidth
                    : box.maxHeight * 1.5;
                return _HeroParallax(
                  child: Image.asset(
                    imageAsset,
                    fit: BoxFit.cover,
                    cacheWidth:
                        math.min(1080, (coverWidth * dpr * 1.2).round()),
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: Color(0xFF1B1B24)),
                  ),
                );
              },
            ),
          ),
        ),
        // Shade behind all hero content stays dark in both themes, so the
        // white text and icons read on any photo.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0B0B0B).withValues(alpha: 0.72),
                  const Color(0xFF0B0B0B).withValues(alpha: 0.50),
                  const Color(0xFF0B0B0B).withValues(alpha: 0.70),
                  const Color(0xFF0B0B0B).withValues(alpha: 0.82),
                ],
                stops: const [0, 0.22, 0.62, 1],
              ),
            ),
          ),
        ),
        // The fade into the page ground happens only in the empty strip
        // under the content, never behind the verse actions.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _groundFadeHeight,
          child: DecoratedBox(
            key: const Key('home_hero_ground_fade'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [ground.withValues(alpha: 0), ground],
              ),
            ),
          ),
        ),
        Padding(
          padding:
              EdgeInsets.fromLTRB(0, topInset + 12, 0, _groundFadeHeight + 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Room for the header, which HomeScrollView pins on top.
              const SizedBox(height: homeHeaderHeight),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: _onScene,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFFC9C9D2),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 56),
              _HeroScrollFade(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: verse,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The verse-of-the-day block inside [HomeVerseHero], driven by
/// [DailyVerseBloc].
class HomeDailyVerse extends StatelessWidget {
  final VoidCallback? onStudy;
  final bool isDisabled;

  const HomeDailyVerse({super.key, this.onStudy, this.isDisabled = false});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DailyVerseBloc, DailyVerseState>(
      builder: (context, state) => HomeDailyVerseView(
        state: state,
        onStudy: onStudy,
        isDisabled: isDisabled,
        onRetry: () => context.read<DailyVerseBloc>().add(const RefreshVerse()),
        onInitial: () =>
            context.read<DailyVerseBloc>().add(const LoadTodaysVerse()),
      ),
    );
  }
}

/// Pure view of the verse block for a given [state]; split from
/// [HomeDailyVerse] so each state can be rendered in tests without a bloc.
class HomeDailyVerseView extends StatelessWidget {
  final DailyVerseState state;
  final VoidCallback? onStudy;
  final VoidCallback onRetry;
  final VoidCallback? onInitial;
  final bool isDisabled;

  const HomeDailyVerseView({
    super.key,
    required this.state,
    required this.onRetry,
    this.onStudy,
    this.onInitial,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s is DailyVerseLoaded) return _loaded(context, s);
    if (s is DailyVerseOffline) return _offline(context, s);
    if (s is DailyVerseError) return _error(context);
    if (s is! DailyVerseLoading && onInitial != null) {
      // Initial state: nothing has asked for today's verse yet.
      WidgetsBinding.instance.addPostFrameCallback((_) => onInitial!());
    }
    return _loading(context);
  }

  Widget _eyebrow(BuildContext context, String date) {
    final label = context.tr(TranslationKeys.dailyVerseOfTheDay);
    final style = AppFonts.inter(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.6,
      color: AppColors.brandGold,
    );
    // Two pieces in a Wrap: on a narrow screen the date moves to the next
    // line whole instead of being cut mid-year.
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        Text(label.toUpperCase(), style: style),
        Text('· ${date.toUpperCase()}', style: style),
      ],
    );
  }

  Widget _verseText(String text) {
    return Text(
      text,
      key: const Key('home_verse_text'),
      maxLines: homeVerseMaxLines,
      overflow: TextOverflow.ellipsis,
      style: AppFonts.poppins(
        fontSize: homeVerseFontSize(text),
        fontWeight: FontWeight.w600,
        color: _onScene,
        height: 1.3,
      ),
    );
  }

  Widget _loaded(BuildContext context, DailyVerseLoaded s) {
    final enabled = onStudy != null && !isDisabled;
    final reference =
        '${s.verse.getReferenceText(s.currentLanguage)} · ${dailyVerseTranslationAbbr(s.currentLanguage)}';

    return AnimatedOpacity(
      opacity: isDisabled ? 0.5 : 1,
      duration: const Duration(milliseconds: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow(context, s.formattedDate),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: enabled ? onStudy : null,
            child: _verseText(s.currentVerseText),
          ),
          const SizedBox(height: 10),
          // Citation taps through to the translation's copyright page.
          GestureDetector(
            onTap: () => context.push(AppRoutes.bibleAttribution),
            child: Text(
              reference,
              style: AppFonts.inter(fontSize: 13, color: _onSceneMuted),
            ),
          ),
          const SizedBox(height: 18),
          // Wrap, not Row: the button keeps its full label and, when the
          // line is too narrow (small phone, long Malayalam label), the
          // icons drop to a second line instead of the label being cut.
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                _StudyNowButton(onPressed: enabled ? onStudy : null),
                DailyVerseActions(state: s, iconColor: _onScene, gap: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _offline(BuildContext context, DailyVerseOffline s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.wifi_off,
                size: 14, color: AppColors.onGradientWarning),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                context.tr(TranslationKeys.dailyVerseOfflineMode),
                style: AppFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _onScene,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _verseText(s.currentVerseText),
        const SizedBox(height: 10),
        Text(
          s.verse.getReferenceText(s.currentLanguage),
          style: AppFonts.inter(fontSize: 13, color: _onSceneMuted),
        ),
      ],
    );
  }

  Widget _error(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(TranslationKeys.dailyVerseUnableToLoad),
          style: AppFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _onScene,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.tr(TranslationKeys.dailyVerseSomethingWentWrong),
          style: AppFonts.inter(fontSize: 13, color: _onSceneMuted),
        ),
        const SizedBox(height: 16),
        // The only place the verse offers a refresh: when it failed to load.
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(context.tr(TranslationKeys.homeTryAgain)),
          style: OutlinedButton.styleFrom(
            foregroundColor: _onScene,
            side: BorderSide(color: _onScene.withValues(alpha: 0.5)),
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _loading(BuildContext context) {
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
          widthFactor: widthFactor,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );

    return Semantics(
      label: context.tr(TranslationKeys.dailyVerseLoading),
      child: Column(
        key: const Key('home_verse_loading'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(0.45, 10),
          const SizedBox(height: 14),
          bar(1, 24),
          const SizedBox(height: 10),
          bar(0.8, 24),
          const SizedBox(height: 14),
          bar(0.35, 12),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

class _StudyNowButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _StudyNowButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF2E28A3);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.5),
        disabledForegroundColor: ink.withValues(alpha: 0.6),
        shape: const StadiumBorder(),
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr(TranslationKeys.homeStudyNow),
            style: AppFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: onPressed == null ? ink.withValues(alpha: 0.6) : ink,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward, size: 16),
        ],
      ),
    );
  }
}

/// Height of the header row (logo, Memory Verses, Settings).
const double homeHeaderHeight = 44;

/// Scroll distance over which the pinned header's page-coloured backdrop
/// fades in. Short, so content never shows through half-covered text.
const double homeHeaderSolidAfter = 24;

/// Asks home to scroll back to the top: the Home tab, tapped while already
/// on home, sends this.
class HomeScrollToTop extends ChangeNotifier {
  HomeScrollToTop._();

  static final HomeScrollToTop instance = HomeScrollToTop._();

  void request() => notifyListeners();
}

/// Home's scroll container with a pinned header.
///
/// The header (logo, Memory Verses, Settings) never scrolls: at the top it
/// sits see-through on the hero photo; as soon as the page moves it gains a
/// backdrop in the page colour (with a hairline), so content slides under a
/// solid bar instead of the header being sliced in half. [headerBuilder] is
/// told when the header is on the page colour, so in light theme it can
/// switch its white-on-photo colours to dark ones; the status-bar icons
/// follow the same switch.
class HomeScrollView extends StatefulWidget {
  final List<Widget> children;
  final Widget Function(BuildContext context, bool onGround)? headerBuilder;

  const HomeScrollView({
    super.key,
    required this.children,
    this.headerBuilder,
  });

  @override
  State<HomeScrollView> createState() => _HomeScrollViewState();
}

class _HomeScrollViewState extends State<HomeScrollView> {
  final ScrollController _controller = ScrollController();
  late final _ScrollAnimation _backdrop = _ScrollAnimation(
      _controller, (o) => (o / homeHeaderSolidAfter).clamp(0.0, 1.0));
  bool _onGround = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    HomeScrollToTop.instance.addListener(_scrollToTop);
  }

  // Rebuilds only when the header crosses onto / off the page colour, not
  // on every scroll frame; the backdrop fade runs on its own layer.
  void _onScroll() {
    final onGround = _controller.offset > homeHeaderSolidAfter / 2;
    if (onGround != _onGround) setState(() => _onGround = onGround);
  }

  void _scrollToTop() {
    if (!_controller.hasClients || _controller.offset == 0) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpTo(0);
    } else {
      _controller.animateTo(0,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    HomeScrollToTop.instance.removeListener(_scrollToTop);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final topInset = MediaQuery.paddingOf(context).top;
    final overlay = _onGround && light
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light;
    final header = widget.headerBuilder;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      // Fill the screen: the pinned header must span the full width however
      // narrow the scrolled content is.
      child: Stack(
        fit: StackFit.expand,
        children: [
          _HomeScrollScope(
            controller: _controller,
            child: SingleChildScrollView(
              controller: _controller,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: FadeTransition(
                      key: const Key('home_header_backdrop'),
                      opacity: _backdrop,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          border: Border(
                            bottom: BorderSide(
                              color: theme.dividerColor.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(18, topInset + 12, 18, 10),
                  child: SizedBox(
                    key: const Key('home_pinned_header'),
                    height: homeHeaderHeight,
                    width: double.infinity,
                    child: header?.call(context, _onGround),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeScrollScope extends InheritedWidget {
  final ScrollController controller;

  const _HomeScrollScope({required this.controller, required super.child});

  static ScrollController? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_HomeScrollScope>()
      ?.controller;

  @override
  bool updateShouldNotify(_HomeScrollScope old) => old.controller != controller;
}

/// How far the hero photo lags behind the page (0 = scrolls with it,
/// 1 = pinned). Kept low so it reads as depth, not as a sliding backdrop.
const double homeHeroParallax = 0.35;

/// The home scroll offset as an [Animation], so transitions can listen to
/// it directly (no widget rebuilds per scroll frame).
class _ScrollAnimation extends Animation<double>
    with
        AnimationLazyListenerMixin,
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin {
  final ScrollController controller;
  final double Function(double offset) map;

  _ScrollAnimation(this.controller, this.map);

  @override
  double get value => map(controller.hasClients ? controller.offset : 0);

  @override
  AnimationStatus get status => AnimationStatus.forward;

  @override
  void didStartListening() => controller.addListener(notifyListeners);

  @override
  void didStopListening() => controller.removeListener(notifyListeners);
}

/// Parallax for the hero photo: while the page scrolls up the photo moves
/// at a fraction of the speed and eases in scale. The photo sits in its own
/// [RepaintBoundary], so each frame only moves an already-painted layer.
/// Static when reduced motion is on or outside [HomeScrollView].
class _HeroParallax extends StatefulWidget {
  final Widget child;

  const _HeroParallax({required this.child});

  @override
  State<_HeroParallax> createState() => _HeroParallaxState();
}

class _HeroParallaxState extends State<_HeroParallax> {
  ScrollController? _controller;
  _ScrollAnimation? _shift;
  _ScrollAnimation? _scale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = _HomeScrollScope.of(context);
    if (controller != _controller) {
      _controller = controller;
      _shift = controller == null
          ? null
          : _ScrollAnimation(
              controller, (o) => o.clamp(0.0, 600.0) * homeHeroParallax / 440);
      _scale = controller == null
          ? null
          : _ScrollAnimation(controller, (o) => 1 + o.clamp(0.0, 600.0) / 3000);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = RepaintBoundary(child: widget.child);
    if (_shift == null || MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return SlideTransition(
      position:
          _shift!.drive(Tween(begin: Offset.zero, end: const Offset(0, 1))),
      child: ScaleTransition(scale: _scale!, child: child),
    );
  }
}

/// Fades the hero's text as it scrolls off, so it leaves softly rather
/// than being sliced by the top of the screen. Fully bright for the first
/// 120px, so a small scroll never makes the verse look disabled.
class _HeroScrollFade extends StatefulWidget {
  final Widget child;

  const _HeroScrollFade({required this.child});

  @override
  State<_HeroScrollFade> createState() => _HeroScrollFadeState();
}

class _HeroScrollFadeState extends State<_HeroScrollFade> {
  ScrollController? _controller;
  _ScrollAnimation? _opacity;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = _HomeScrollScope.of(context);
    if (controller != _controller) {
      _controller = controller;
      _opacity = controller == null
          ? null
          : _ScrollAnimation(
              controller, (o) => (1 - (o - 120) / 240).clamp(0.0, 1.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_opacity == null || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return FadeTransition(opacity: _opacity!, child: widget.child);
  }
}

/// One orchestrated entrance: each section under the hero rises 12px and
/// fades in, staggered by [index], the first time home is shown. Home stays
/// mounted across tabs, so this plays once per app open. Uses transitions
/// (no rebuilds) and is skipped entirely when reduced motion is on.
class HomeEntrance extends StatefulWidget {
  final int index;
  final Widget child;

  const HomeEntrance({super.key, required this.index, required this.child});

  @override
  State<HomeEntrance> createState() => _HomeEntranceState();
}

class _HomeEntranceState extends State<HomeEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  late final Animation<Offset> _rise =
      _curve.drive(Tween(begin: const Offset(0, 0.06), end: Offset.zero));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(position: _rise, child: widget.child),
    );
  }
}
