import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                        const SizedBox(height: 4),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    child: _ButtonLabel(
                        icon: _primaryIcon, label: _primaryLabel()),
                  ),
                  const SizedBox(height: 8),
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
                          fontSize: 14, fontWeight: FontWeight.w600),
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
    return _StartWithCard(child: content);
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
          style: AppFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: palette.text,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          verse.reference,
          style: AppFonts.inter(fontSize: 12, color: palette.muted),
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
        for (final other in _otherOfficials)
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
    );
  }
}

/// 220px photo header with a dark scrim, × and the gold eyebrow and title.
class _IntroHeader extends StatelessWidget {
  final NewForYouKind kind;
  final VoidCallback onClose;

  const _IntroHeader({required this.kind, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final onPhoto = ReaderPalette.resolve(
      isDark: true,
      page: Theme.of(context).scaffoldBackgroundColor,
    );
    final name = kind.name;
    return Stack(
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
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.72),
                  Colors.black.withValues(alpha: 0.86),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 220),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: onClose,
                    tooltip: context.tr(TranslationKeys.introClose),
                    icon: const Icon(Icons.close_rounded, size: 22),
                    color: onPhoto.text,
                  ),
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context
                              .tr(TranslationKeys.introEyebrow(name))
                              .toUpperCase(),
                          style: AppFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: onPhoto.gold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Semantics(
                          header: true,
                          child: Text(
                            context.tr(TranslationKeys.introTitle(name)),
                            style: AppFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
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
        ),
      ],
    );
  }
}

/// Numbered step: gold 24px number, 14pt title, 13pt muted body.
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.selectedFill,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: AppFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: palette.onSelected,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: palette.muted,
                    height: 1.35,
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

/// Soft gold-tinted card with the "Start with" eyebrow.
class _StartWithCard extends StatelessWidget {
  final Widget child;

  const _StartWithCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      key: const Key('intro_start_with'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          palette.gold.withValues(alpha: palette.isDark ? 0.08 : 0.06),
          palette.card,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.gold.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr(TranslationKeys.introStartWith).toUpperCase(),
            style: AppFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: palette.gold,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
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

/// A 32px tappable pill (generate examples, the discipler question).
class _Chip extends StatelessWidget {
  final String label;
  final Color fill;
  final Color ink;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.fill,
    required this.ink,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: fill,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Text(
                label,
                style: AppFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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

/// The person's-language official fellowship with its Join pill.
class _OfficialFellowshipCard extends StatelessWidget {
  final PublicFellowshipEntity fellowship;
  final VoidCallback? onJoin;

  const _OfficialFellowshipCard({required this.fellowship, this.onJoin});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final study = fellowship.currentStudyTitle?.trim() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.gold.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _FellowshipAvatar(fellowship: fellowship, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fellowship.name,
                      style: AppFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                    Text(
                      context.tr(TranslationKeys.introFellowshipsMembersOpen,
                          {'n': fellowship.memberCount}),
                      style: AppFonts.inter(fontSize: 12, color: palette.muted),
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
                            fontSize: 12,
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
          const SizedBox(height: 8),
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
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: palette.raised,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text:
                        '${context.tr(TranslationKeys.introFellowshipsStudying)}  ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: study),
                ]),
                style: AppFonts.inter(fontSize: 12, color: palette.text),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: palette.muted),
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
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              _FellowshipAvatar(fellowship: fellowship, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  fellowship.name,
                  style: AppFonts.inter(
                    fontSize: 13,
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
                style: AppFonts.inter(fontSize: 12, color: palette.muted),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: palette.dim),
            ],
          ),
        ),
      ),
    );
  }
}

class _FellowshipAvatar extends StatelessWidget {
  final PublicFellowshipEntity fellowship;
  final double size;

  const _FellowshipAvatar({required this.fellowship, required this.size});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final name = fellowship.name.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.selectedFill,
        shape: BoxShape.circle,
      ),
      child: Text(
        name.isEmpty ? 'D' : name.characters.first.toUpperCase(),
        style: AppFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: palette.onSelected,
        ),
      ),
    );
  }
}
