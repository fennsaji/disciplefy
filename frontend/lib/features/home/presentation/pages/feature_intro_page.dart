import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_needed_sheet.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/public_fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/home/domain/new_for_you/feature_intro_content.dart';
import 'package:disciplefy_bible_study/features/home/domain/new_for_you/feature_intro_source.dart';
import 'package:disciplefy_bible_study/features/home/domain/new_for_you/new_for_you_scheduler.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/choose_first_path_card.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/guest_path_lock.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

/// Official groups in the "Start with" card: the person's language first,
/// then this many in other languages.
const int _otherFellowshipRows = 2;

/// Introduction to one feature, opened from its "New for you" banner: photo
/// header with the title, three numbered steps, a "Start with" example, one
/// primary action that goes to the feature and a secondary one.
class FeatureIntroPage extends StatefulWidget {
  final NewForYouKind kind;

  const FeatureIntroPage({super.key, required this.kind});

  @override
  State<FeatureIntroPage> createState() => _FeatureIntroPageState();
}

class _FeatureIntroPageState extends State<FeatureIntroPage> {
  FeatureIntroSource? _source;
  late final String _language;

  List<LearningPath>? _paths;
  IntroVerse? _verse;
  bool _verseLoaded = false;
  PublicFellowshipEntity? _official;
  List<PublicFellowshipEntity> _otherOfficials = const [];
  bool _fellowshipsLoaded = false;
  bool _busy = false;

  NewForYouKind get _kind => widget.kind;
  String get _name => _kind.name;

  @override
  void initState() {
    super.initState();
    _source =
        sl.isRegistered<FeatureIntroSource>() ? sl<FeatureIntroSource>() : null;
    _language = sl.isRegistered<TranslationService>()
        ? sl<TranslationService>().currentLanguage.code
        : AppLanguage.english.code;
    _load();
  }

  Future<void> _load() async {
    final source = _source;
    switch (_kind) {
      case NewForYouKind.paths:
        final paths = source == null
            ? const <LearningPath>[]
            : await source.startPaths(
                guest: AccountGate.isActive, language: _language);
        if (mounted) setState(() => _paths = paths);
      case NewForYouKind.memory:
        final verse = await source?.todaysVerse(_language);
        if (mounted) {
          setState(() {
            _verse = verse;
            _verseLoaded = true;
          });
        }
      case NewForYouKind.fellowships:
        final all = await source?.officialFellowships() ?? const [];
        final open = all
            .where((f) => f.isUnlimited || f.memberCount < (f.maxMembers ?? 0))
            .toList();
        if (!mounted) return;
        setState(() {
          _official = open.where((f) => f.language == _language).firstOrNull;
          _otherOfficials = open
              .where((f) => f.language != _language)
              .take(_otherFellowshipRows)
              .toList();
          _fellowshipsLoaded = true;
        });
      case NewForYouKind.generate:
      case NewForYouKind.discipler:
        break;
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _primary() => _run(() async {
        switch (_kind) {
          case NewForYouKind.paths:
            context.go(AppRoutes.studyTopics);
          case NewForYouKind.memory:
            await _practiseTodaysVerse();
          case NewForYouKind.generate:
            await _startStudy(featureIntroExamplePassage);
          case NewForYouKind.discipler:
            await _ask(context.tr(TranslationKeys.introDisciplerQuestion));
          case NewForYouKind.fellowships:
            await _joinOfficial();
        }
      });

  Future<void> _secondary() => _run(() async {
        switch (_kind) {
          case NewForYouKind.paths:
          case NewForYouKind.discipler:
            _close();
          case NewForYouKind.memory:
            if (await requireAccount(context, AccountReason.memoryVerses) &&
                mounted) {
              context.go(AppRoutes.memoryVerses);
            }
          case NewForYouKind.generate:
            context.go(Uri(path: AppRoutes.studyGuideV2, queryParameters: {
              'input': featureIntroExamplePassage,
              'type': 'scripture',
              'language': _language,
              'mode': 'quick',
              'source': 'home',
            }).toString());
          case NewForYouKind.fellowships:
            if (await requireAccount(context, AccountReason.community) &&
                mounted) {
              context.go(AppRoutes.community);
            }
        }
      });

  Future<void> _practiseTodaysVerse() async {
    if (!await requireAccount(context, AccountReason.memoryVerses) ||
        !mounted) {
      return;
    }
    final verse = _verse;
    if (verse != null && _source != null) {
      final saved = await _source!.saveVerse(verse);
      if (!mounted) return;
      if (!saved) {
        showAppSnackBar(
            context, context.tr(TranslationKeys.commonErrorTryAgain),
            tone: AppSnackTone.error);
        return;
      }
      showAppSnackBar(context, context.tr(TranslationKeys.introMemorySaved),
          tone: AppSnackTone.success);
    }
    context.go(AppRoutes.memoryVerses);
  }

  Future<void> _startStudy(String input) async {
    if (!await requireAccount(context, AccountReason.generate) || !mounted) {
      return;
    }
    context
        .go('${AppRoutes.generateStudy}?prefill=${Uri.encodeComponent(input)}');
  }

  Future<void> _ask(String question) async {
    if (!await requireAccount(context, AccountReason.discipler) || !mounted) {
      return;
    }
    context
        .go('${AppRoutes.discipler}?prefill=${Uri.encodeComponent(question)}');
  }

  Future<void> _joinOfficial() async {
    if (!await requireAccount(context, AccountReason.community) || !mounted) {
      return;
    }
    final official = _official;
    if (official != null && _source != null) {
      final joined = await _source!.joinFellowship(official.id);
      if (!mounted) return;
      if (!joined) {
        showAppSnackBar(
            context, context.tr(TranslationKeys.introFellowshipsJoinFailed),
            tone: AppSnackTone.error);
        return;
      }
    }
    context.go(AppRoutes.community);
  }

  void _openPath(LearningPath path) {
    guestPathGate(context, path, () async {
      if (!mounted) return;
      await context.push<bool>('/learning-path/${path.id}?source=home');
    });
  }

  String _primaryLabel() {
    if (_kind == NewForYouKind.fellowships) {
      return context.tr(TranslationKeys.introPrimary(_name),
          {'name': _official?.name ?? 'Disciplefy'});
    }
    return context.tr(TranslationKeys.introPrimary(_name));
  }

  IconData get _primaryIcon => switch (_kind) {
        NewForYouKind.paths => Icons.map_outlined,
        NewForYouKind.memory => Icons.timer_outlined,
        NewForYouKind.generate => Icons.menu_book_outlined,
        NewForYouKind.discipler => Icons.help_outline_rounded,
        NewForYouKind.fellowships => Icons.group_add_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _IntroHeader(kind: _kind, onClose: _close),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var n = 1; n <= featureIntroStepCount; n++)
                          _IntroStep(
                            key: Key('intro_step_$n'),
                            number: n,
                            title: context
                                .tr(TranslationKeys.introStepTitle(_name, n)),
                            body: context
                                .tr(TranslationKeys.introStepBody(_name, n)),
                          ),
                        _startWith(palette),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    key: const Key('intro_primary'),
                    onPressed: _busy ? null : _primary,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.ctaFill,
                      foregroundColor: palette.ctaInk,
                      disabledBackgroundColor: palette.disabledFill,
                      disabledForegroundColor: palette.disabledInk,
                      minimumSize: const Size.fromHeight(40),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: const StadiumBorder(),
                      textStyle: AppFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    child: _ButtonLabel(
                        icon: _primaryIcon, label: _primaryLabel()),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('intro_secondary'),
                    onPressed: _busy ? null : _secondary,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.text,
                      side: BorderSide(color: palette.outline),
                      minimumSize: const Size.fromHeight(40),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: const StadiumBorder(),
                      textStyle: AppFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    child: Text(
                      context.tr(TranslationKeys.introSecondary(_name)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _startWith(ReaderPalette palette) {
    final Widget? content = switch (_kind) {
      NewForYouKind.paths => _pathsContent(),
      NewForYouKind.memory => _memoryContent(palette),
      NewForYouKind.generate => _generateContent(palette),
      NewForYouKind.discipler => _disciplerContent(palette),
      NewForYouKind.fellowships => _fellowshipsContent(palette),
    };
    if (content == null) return const SizedBox.shrink();
    // The fellowship card is a card of its own: no box around it.
    return _StartWithCard(
      boxed: _kind != NewForYouKind.fellowships,
      child: content,
    );
  }

  Widget? _pathsContent() {
    final paths = _paths;
    if (paths == null) return const _Loading();
    if (paths.isEmpty) return null;
    return Column(
      children: [
        for (final path in paths)
          FirstPathRow(path: path, onTap: () => _openPath(path)),
      ],
    );
  }

  Widget? _memoryContent(ReaderPalette palette) {
    if (!_verseLoaded) return const _Loading();
    final verse = _verse;
    if (verse == null) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '“${verse.text}”',
          style: AppFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: palette.text,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          verse.reference,
          style: AppFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w500, color: palette.muted),
        ),
      ],
    );
  }

  Widget _generateContent(ReaderPalette palette) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final key in const [
          TranslationKeys.introGenerateChip1,
          TranslationKeys.introGenerateChip2,
          TranslationKeys.introGenerateChip3,
        ])
          _Chip(
            label: context.tr(key),
            fill: palette.raised,
            ink: palette.text,
            onTap: () => _run(() => _startStudy(context.tr(key))),
          ),
      ],
    );
  }

  Widget _disciplerContent(ReaderPalette palette) {
    final question = context.tr(TranslationKeys.introDisciplerQuestion);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: _Chip(
        label: question,
        fill: palette.selectedFill,
        ink: palette.onSelected,
        bubble: true,
        onTap: () => _run(() => _ask(question)),
      ),
    );
  }

  Widget? _fellowshipsContent(ReaderPalette palette) {
    if (!_fellowshipsLoaded) return const _Loading();
    final official = _official;
    if (official == null && _otherOfficials.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (official != null)
          _OfficialFellowshipCard(
            fellowship: official,
            onJoin: _busy ? null : () => _run(_joinOfficial),
          ),
        for (final other in _otherOfficials) ...[
          if (other != _otherOfficials.first)
            Divider(height: 1, thickness: 1, color: palette.hairline),
          _FellowshipRow(
            fellowship: other,
            onTap: () => _run(() async {
              if (await requireAccount(context, AccountReason.community) &&
                  mounted) {
                context.go(AppRoutes.community);
              }
            }),
          ),
        ],
      ],
    );
  }
}

/// Photo header with the shade, ×, gold eyebrow and title. In dark theme
/// the photo fades into the page; in light theme it ends in a rounded edge.
class _IntroHeader extends StatelessWidget {
  final NewForYouKind kind;
  final VoidCallback onClose;

  const _IntroHeader({required this.kind, required this.onClose});

  static const double _lightRadius = 28;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final ground = theme.scaffoldBackgroundColor;
    final onPhoto = ReaderPalette.resolve(
      isDark: true,
      page: ground,
    );
    final name = kind.name;
    final header = Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: Image.asset(
              newForYouPhotos[kind]!,
              fit: BoxFit.cover,
              cacheWidth: 900,
              errorBuilder: (_, __, ___) => ColoredBox(color: onPhoto.card),
            ),
          ),
        ),
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
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),
        // Dark theme: the photo fades into the page under the title.
        if (!isLight)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 24,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [ground.withValues(alpha: 0), ground],
                ),
              ),
            ),
          ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 0, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: onClose,
                  tooltip: context.tr(TranslationKeys.introClose),
                  icon: const Icon(Icons.close_rounded, size: 22),
                  color: onPhoto.text,
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context
                            .tr(TranslationKeys.introEyebrow(name))
                            .toUpperCase(),
                        style: AppFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.6,
                          color: onPhoto.gold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        header: true,
                        child: Text(
                          context.tr(TranslationKeys.introTitle(name)),
                          style: AppFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: onPhoto.text,
                            height: 1.25,
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
      ],
    );
    if (!isLight) return header;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: ClipRRect(
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(_lightRadius)),
        child: header,
      ),
    );
  }
}

/// Numbered step: a 26px gold-tinted number, 14.5pt title, 12.5pt body.
class _IntroStep extends StatelessWidget {
  final int number;
  final String title;
  final String body;

  const _IntroStep({
    super.key,
    required this.number,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final dark = palette.isDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dark
                  ? palette.gold.withValues(alpha: 0.10)
                  : const Color(0xFFFFEEC0),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: AppFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                // Light: the design's deep amber on the pale gold, 7.6:1.
                color: dark ? palette.gold : AppColors.brandGoldInk,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  body,
                  style: AppFonts.inter(
                    fontSize: 12.5,
                    color: palette.muted,
                    height: 1.25,
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

/// "Start with" eyebrow and its example, in a soft gold box unless [boxed]
/// is false (the example is a card itself).
class _StartWithCard extends StatelessWidget {
  final Widget child;
  final bool boxed;

  const _StartWithCard({required this.child, this.boxed = true});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr(TranslationKeys.introStartWith).toUpperCase(),
          style: AppFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
            color: palette.gold,
          ),
        ),
        SizedBox(height: boxed ? 8 : 10),
        child,
      ],
    );
    if (!boxed) {
      return KeyedSubtree(key: const Key('intro_start_with'), child: content);
    }
    return Container(
      key: const Key('intro_start_with'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.gold.withValues(alpha: 0.15)),
      ),
      child: content,
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
}

/// Icon and label of the primary action; the label wraps rather than
/// truncating.
class _ButtonLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ButtonLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 8),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
  }
}

/// A 32px tappable pill (generate examples), or a speech bubble with a
/// square lower-right corner ([bubble], the discipler question).
class _Chip extends StatelessWidget {
  final String label;
  final Color fill;
  final Color ink;
  final VoidCallback onTap;
  final bool bubble;

  const _Chip({
    required this.label,
    required this.fill,
    required this.ink,
    required this.onTap,
    this.bubble = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: fill,
        shape: bubble
            ? const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              )
            : const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: bubble ? 37 : 32),
            child: Padding(
              padding: bubble
                  ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                  : const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Text(
                label,
                style: AppFonts.inter(
                  fontSize: bubble ? 14 : 13,
                  fontWeight: bubble ? FontWeight.w500 : FontWeight.w600,
                  color: ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The person's-language official fellowship with its Join pill, on a
/// gold-washed card.
class _OfficialFellowshipCard extends StatelessWidget {
  final PublicFellowshipEntity fellowship;
  final VoidCallback? onJoin;

  const _OfficialFellowshipCard({required this.fellowship, this.onJoin});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final dark = palette.isDark;
    final study = fellowship.currentStudyTitle?.trim() ?? '';
    // Secondary text on the gold wash: the design's warm brown on light.
    final sub = dark ? const Color(0xFFD6D6DC) : const Color(0xFF5B4A1F);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF1F1F27), Color(0xFF2A2214), Color(0xFF5C4313)]
              : const [Color(0xFFFFF6DD), Color(0xFFFBE3A6)],
          stops: dark ? const [0, 0.6, 1] : null,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.brandGold.withValues(alpha: dark ? 0.25 : 0.60),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : ReaderPalette.ink,
                  border: Border.all(
                    color: dark
                        ? AppColors.brandGold.withValues(alpha: 0.40)
                        : Colors.white.withValues(alpha: 0.60),
                  ),
                ),
                child: Image.asset(
                  'assets/images/logo_transparent.png',
                  fit: BoxFit.contain,
                  cacheWidth: 96,
                  errorBuilder: (_, __, ___) =>
                      _FellowshipAvatar(fellowship: fellowship, size: 30),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fellowship.name,
                      style: AppFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.people_outline, size: 12, color: sub),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            context.tr(
                                TranslationKeys.introFellowshipsMembersOpen,
                                {'n': fellowship.memberCount}),
                            style: AppFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: sub),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                child: Material(
                  color: palette.ctaFill,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onJoin,
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(minHeight: 32, minWidth: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        child: Text(
                          context.tr(TranslationKeys.introFellowshipsJoin),
                          textAlign: TextAlign.center,
                          style: AppFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.ctaInk,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Tag(
                icon: Icons.verified_outlined,
                label: context.tr(TranslationKeys.introFellowshipsOfficial),
              ),
              _Tag(
                  label: AppLanguage.fromCode(fellowship.language).displayName),
            ],
          ),
          if (study.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: dark
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.60),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(Icons.menu_book_outlined,
                        size: 14, color: dark ? AppColors.brandGold : sub),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text:
                              '${context.tr(TranslationKeys.introFellowshipsStudying)}  ',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: palette.text),
                        ),
                        TextSpan(text: study),
                      ]),
                      style: AppFonts.inter(fontSize: 12.5, color: sub),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData? icon;
  final String label;

  const _Tag({this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final dark = palette.isDark;
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark
              ? palette.outline
              : AppColors.brandGold.withValues(alpha: 0.40),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: palette.text),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: AppFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.text)),
        ],
      ),
    );
  }
}

/// An official fellowship in another language.
class _FellowshipRow extends StatelessWidget {
  final PublicFellowshipEntity fellowship;
  final VoidCallback onTap;

  const _FellowshipRow({required this.fellowship, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
          child: Row(
            children: [
              _FellowshipAvatar(fellowship: fellowship, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  fellowship.name,
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                context.tr(
                    fellowship.memberCount == 1
                        ? TranslationKeys.introFellowshipsMemberOne
                        : TranslationKeys.introFellowshipsMembers,
                    {'n': fellowship.memberCount}),
                style: AppFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: palette.muted),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 16, color: palette.dim),
            ],
          ),
        ),
      ),
    );
  }
}

/// A fellowship's initial (its script's first letter) on a gold disc.
class _FellowshipAvatar extends StatelessWidget {
  final PublicFellowshipEntity fellowship;
  final double size;

  const _FellowshipAvatar({required this.fellowship, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6D88A), Color(0xFFD9982A)],
        ),
      ),
      child: Text(
        _initial(),
        style: AppFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: ReaderPalette.ink,
        ),
      ),
    );
  }

  /// The language's own letter ("हि", "മ") for a fellowship in another
  /// script, else the name's first letter.
  String _initial() {
    switch (fellowship.language) {
      case 'hi':
        return 'हि';
      case 'ml':
        return 'മ';
    }
    final name = fellowship.name.trim();
    return name.isEmpty ? 'D' : name.characters.first.toUpperCase();
  }
}
