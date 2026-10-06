import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/error_message_sanitizer.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/core/widgets/upgrade_dialog.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/entities/daily_verse_entity.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_state.dart';
import 'package:disciplefy_bible_study/features/study_generation/data/repositories/token_cost_repository.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/mappers/app_language_mapper.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/utils/detect_study_input.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/utils/scripture_reference.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/pages/generate_study_screen.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/services/study_launch_service.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/generate_hero.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/mode_selection_sheet.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/recent_guides_section.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/simple/depth_switch.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/simple/input_type_tag.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/simple/language_pill.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/simple/verse_of_day_row.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_mode_labels.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/widgets/out_of_credits_sheet.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_status.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_event.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

/// Generate tab with one input: the text is read as a verse, a topic or a
/// question, the user picks Quick Read or Standard (or any depth via
/// "All 5"), and "Generate study" opens the streaming guide straight away.
class GenerateSimpleScreen extends StatefulWidget {
  /// Text to start with in the input (e.g. from a deep link).
  final String? prefill;

  const GenerateSimpleScreen({super.key, this.prefill});

  @override
  State<GenerateSimpleScreen> createState() => _GenerateSimpleScreenState();
}

class _GenerateSimpleScreenState extends State<GenerateSimpleScreen>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  DetectedInput _detected = detectStudyInput('');
  DetectedInputType? _override;
  String _lastText = '';
  String? _error;
  StudyMode _mode = StudyMode.quick;
  final Map<StudyMode, int> _costs = {};

  StudyLanguage _language = StudyLanguage.english;
  bool _languageIsDefault = true;
  bool _launching = false;

  Timer? _detectTimer;
  StreamSubscription<AppLanguage>? _languageChanges;
  GoRouter? _router;
  String? _lastPath;

  late final LanguagePreferenceService _languages =
      sl<LanguagePreferenceService>();
  late final SystemConfigService _config = sl<SystemConfigService>();
  late final TokenCostRepository _costRepository = sl<TokenCostRepository>();

  /// The two depths offered inline; "All 5" opens the rest.
  static const List<StudyMode> _inlineModes = [
    StudyMode.quick,
    StudyMode.standard,
  ];

  static const Duration _detectDelay = Duration(milliseconds: 250);
  static const double _gutter = 20;
  static const double _heroHeight = 400;
  static const double _buttonHeight = 40;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final prefill = widget.prefill?.trim();
    if (prefill != null && prefill.isNotEmpty) {
      _controller.text = prefill;
      _detected = detectStudyInput(prefill);
    }
    _lastText = _controller.text;
    _controller.addListener(_onTextChanged);
    _languageChanges = _languages.languageChanges.listen((_) async {
      if (mounted) await _loadLanguage();
    });
    _loadLanguage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<TokenBloc>().state is! TokenLoaded) {
        context.read<TokenBloc>().add(const GetTokenStatus());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh the balance when the user comes back to this tab.
    if (_router == null) {
      _router = GoRouter.maybeOf(context);
      _lastPath = _router?.routerDelegate.currentConfiguration.uri.path;
      _router?.routerDelegate.addListener(_onRouteChanged);
    }
  }

  @override
  void didUpdateWidget(GenerateSimpleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final prefill = widget.prefill?.trim();
    if (prefill != oldWidget.prefill?.trim() &&
        prefill != null &&
        prefill.isNotEmpty) {
      _controller.text = prefill;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<TokenBloc>().add(const GetTokenStatus());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _detectTimer?.cancel();
    _languageChanges?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onRouteChanged() {
    final path = _router?.routerDelegate.currentConfiguration.uri.path;
    final cameBack = path == AppRoutes.generateStudy &&
        _lastPath != null &&
        _lastPath != AppRoutes.generateStudy;
    _lastPath = path;
    if (cameBack && mounted) {
      context.read<TokenBloc>().add(const RefreshTokenStatus());
    }
  }

  // ---------------------------------------------------------------------------
  // Input
  // ---------------------------------------------------------------------------

  /// Detection rebuilds the scripture pattern, so it runs once typing pauses.
  ///
  /// Any edit to the text drops the manual type (the user re-taps the tag if
  /// detection is still wrong) and the scripture error. Cursor moves alone
  /// keep both.
  void _onTextChanged() {
    final text = _controller.text;
    if (text == _lastText) return;
    _lastText = text;
    _detectTimer?.cancel();
    if (text.trim().isEmpty) {
      setState(() {
        _detected = detectStudyInput('');
        _override = null;
        _error = null;
      });
      return;
    }
    // Rebuild for the clear button; the tag follows after the pause.
    setState(() {
      _override = null;
      _error = null;
    });
    _detectTimer = Timer(_detectDelay, _detectNow);
  }

  void _detectNow() {
    _detectTimer?.cancel();
    if (!mounted) return;
    final detected = detectStudyInput(_controller.text);
    if (detected.text != _detected.text || detected.type != _detected.type) {
      setState(() => _detected = detected);
    }
  }

  /// The detected input, with the user's manual type applied.
  DetectedInput get _input {
    final override = _override;
    if (override == null || override == _detected.type) return _detected;
    final text = _detected.text;
    final minLength = override == DetectedInputType.question ? 10 : 2;
    return DetectedInput(override, text, text.length >= minLength);
  }

  void _cycleType() {
    setState(() {
      _override = InputTypeTag.next(_input.type);
      _error = null;
    });
  }

  void _fill(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _focus.unfocus();
  }

  // ---------------------------------------------------------------------------
  // Language and costs
  // ---------------------------------------------------------------------------

  Future<void> _loadLanguage() async {
    try {
      final language = await _languages.getStudyContentLanguage();
      final isDefault = await _languages.isStudyContentLanguageDefault();
      if (!mounted) return;
      setState(() {
        _language = language.toStudyLanguage();
        _languageIsDefault = isDefault;
      });
    } catch (e) {
      Logger.error('Generate: could not load the study language: $e');
    }
    await _loadCosts();
  }

  Future<void> _switchLanguage(StudyLanguage? language) async {
    try {
      if (language == null) {
        await _languages.saveStudyContentLanguage(null);
        final appLanguage = await _languages.getSelectedLanguage();
        if (!mounted) return;
        setState(() {
          _language = appLanguage.toStudyLanguage();
          _languageIsDefault = true;
        });
      } else {
        await _languages.saveStudyContentLanguage(language.toAppLanguage());
        if (!mounted) return;
        setState(() {
          _language = language;
          _languageIsDefault = false;
        });
      }
    } catch (e) {
      Logger.error('Generate: could not save the study language: $e');
    }
    await _loadCosts();
  }

  /// Credit cost of every depth for the current language. The repository
  /// caches; a failed depth just shows no cost (the backend still decides).
  Future<void> _loadCosts() async {
    final language = _language.code;
    final costs = <StudyMode, int>{};
    for (final mode in StudyMode.values) {
      try {
        final result = await _costRepository.getTokenCost(language, mode.value);
        result.fold(
          (failure) => Logger.warning(
              'Generate: no cost for ${mode.name}: ${ErrorMessageSanitizer.sanitize(failure)}'),
          (cost) => costs[mode] = cost,
        );
      } catch (e) {
        Logger.error('Generate: cost lookup failed for ${mode.name}: $e');
      }
    }
    if (!mounted || language != _language.code) return;
    setState(() {
      _costs
        ..clear()
        ..addAll(costs);
    });
  }

  // ---------------------------------------------------------------------------
  // Depth
  // ---------------------------------------------------------------------------

  TokenStatus? _tokenStatus() {
    final state = context.read<TokenBloc>().state;
    if (state is TokenLoaded) return state.tokenStatus;
    if (state is TokenError) return state.previousTokenStatus;
    return null;
  }

  String get _plan => _tokenStatus()?.userPlan.name ?? 'free';

  bool _isLocked(StudyMode mode) =>
      _config.isFeatureLocked(mode.featureKey, _plan);

  List<StudyMode> get _visibleInlineModes => _inlineModes
      .where((m) => !_config.shouldHideFeature(m.featureKey, _plan))
      .toList();

  void _showUpgrade(StudyMode mode) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UpgradeDialog(
        featureKey: mode.featureKey,
        currentPlan: _plan,
        requiredPlans: _config.getRequiredPlans(mode.featureKey),
        upgradePlan: _config.getUpgradePlan(mode.featureKey, _plan),
      ),
    );
  }

  /// "All 5": the full depth chooser. Its choice becomes the depth, and the
  /// study starts straight away when the input is ready.
  Future<void> _openAllDepths() async {
    _detectNow();
    final input = _input;
    final result = await ModeSelectionSheet.show(
      context: context,
      languageCode: _language.code,
      recommendedMode: recommendedStudyMode,
      preselectedMode: _mode,
      showRememberOption: false,
      eyebrow: input.text.isEmpty ? null : input.text,
    );
    if (result == null || !mounted) return;
    setState(() => _mode = result['mode'] as StudyMode);
    if (input.isValid) await _generate();
  }

  // ---------------------------------------------------------------------------
  // Launch
  // ---------------------------------------------------------------------------

  Future<void> _generate() async {
    _detectNow();
    final input = _input;
    if (!input.isValid) return;
    await _launch(input.text, input.type);
  }

  Future<void> _launchVerse(String reference) =>
      _launch(reference, DetectedInputType.scripture);

  Future<void> _launch(String text, DetectedInputType type) async {
    if (_launching) return;
    // Never send a non-reference as scripture (e.g. a manual type change):
    // the same reference check as the shipped screen.
    if (type == DetectedInputType.scripture &&
        detectStudyInput(text).type != DetectedInputType.scripture &&
        !isScriptureReference(text)) {
      setState(() =>
          _error = context.tr(TranslationKeys.generateStudyScriptureError));
      return;
    }
    if (context.read<ConnectivityBloc>().state is ConnectivityOffline) {
      showAppSnackBar(
        context,
        context.tr(TranslationKeys.studyUiOfflineGenerate),
        tone: AppSnackTone.warning,
      );
      return;
    }
    final mode = _mode;
    if (_isLocked(mode)) {
      _showUpgrade(mode);
      return;
    }

    setState(() => _launching = true);
    final launch = sl<StudyLaunchService>();
    final status = _tokenStatus();
    final cost = _costs[mode] ?? 0;
    final language = _language.code;
    final LaunchDecision decision;
    try {
      decision = await launch.decide(
        input: text,
        type: type.apiValue,
        language: language,
        mode: mode,
        status: status,
        cost: cost,
      );
    } finally {
      if (mounted) setState(() => _launching = false);
    }
    if (!mounted) return;

    if (decision == LaunchDecision.needCredits && status != null) {
      await OutOfCreditsSheet.show(context, status: status, needed: cost);
      return;
    }
    context.go(launch.location(
      input: text,
      type: type.apiValue,
      language: language,
      mode: mode,
    ));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isEmpty = _controller.text.trim().isEmpty;
    final input = _input;
    final showTag = !isEmpty && (input.isValid || _override != null);
    final palette = ReaderPalette.of(context);

    final body = SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.paddingOf(context).bottom + (keyboardVisible ? 20 : 32),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topInset + _heroHeight,
            child: const GenerateHeroBackdrop(),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(_gutter, topInset + 16, _gutter, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                const SizedBox(height: 20),
                _inputField(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      _error!,
                      key: const Key('generate_simple_error'),
                      style: AppFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (showTag) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: InputTypeTag(type: input.type, onTap: _cycleType),
                  ),
                ],
                if (isEmpty) ...[
                  const SizedBox(height: 12),
                  _suggestions(),
                  _verseOfDay(),
                ],
                const SizedBox(height: 24),
                _depthHeader(),
                const SizedBox(height: 8),
                DepthSwitch(
                  modes: _visibleInlineModes,
                  selected: _mode,
                  locked: _inlineModes.where(_isLocked).toSet(),
                  onSelected: (mode) => setState(() => _mode = mode),
                  onLockedTap: _showUpgrade,
                ),
                if (!_inlineModes.contains(_mode)) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${_mode.localizedName(context)} · ${_mode.localizedDuration(context)}',
                    key: const Key('depth_other_label'),
                    textAlign: TextAlign.center,
                    style: AppFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.gold,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _generateButton(input.isValid),
                if (_costs[_mode] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.tr(TranslationKeys.generateSimpleUsingCredits,
                        {'n': '${_costs[_mode]}'}),
                    textAlign: TextAlign.center,
                    style: AppFonts.inter(fontSize: 12, color: palette.muted),
                  ),
                ],
                if (!keyboardVisible) ...[
                  const SizedBox(height: 32),
                  const RecentGuidesSection(),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: palette.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        resizeToAvoidBottomInset: true,
        body: body,
      ),
    );
  }

  /// Gold eyebrow + credit pill, then the headline.
  Widget _header() {
    final palette = ReaderPalette.of(context);
    final ink = GenerateHeroInk.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr(TranslationKeys.generateSimpleEyebrow),
                style: AppFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: palette.gold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            BlocBuilder<TokenBloc, TokenState>(
              builder: (context, state) {
                final TokenStatus? status;
                final bool isStale;
                if (state is TokenLoaded) {
                  status = state.tokenStatus;
                  isStale = false;
                } else if (state is TokenError &&
                    state.previousTokenStatus != null) {
                  status = state.previousTokenStatus;
                  isStale = true;
                } else {
                  return const SizedBox(height: 32);
                }
                return TokenBalancePill(
                  label: status!.isPremium ? '∞' : '${status.totalTokens}',
                  isStale: isStale,
                  onTap: () => context.go(AppRoutes.tokenManagement),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          context.tr(TranslationKeys.generateSimpleTitle),
          style: AppFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            height: 1.2,
            color: ink.text,
          ),
        ),
      ],
    );
  }

  /// White search field with the clear button and the language pill.
  Widget _inputField() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _focus.hasFocus
              ? ReaderPalette.of(context).gold
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded,
              size: 22, color: SearchFieldColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Focus(
              onFocusChange: (_) => setState(() {}),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _generate(),
                cursorColor: SearchFieldColors.ink,
                style: AppFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: SearchFieldColors.ink,
                ),
                decoration: InputDecoration(
                  hintText: context.tr(TranslationKeys.generateSimpleHint),
                  hintMaxLines: 3,
                  hintStyle: AppFonts.inter(
                    fontSize: 14,
                    color: SearchFieldColors.hint,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              onPressed: () {
                _controller.clear();
                _focus.requestFocus();
              },
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: SearchFieldColors.hint),
            ),
          LanguagePill(
            selected: _language,
            isDefault: _languageIsDefault,
            onSelected: _switchLanguage,
          ),
        ],
      ),
    );
  }

  /// One verse and two topics to start from.
  Widget _suggestions() {
    final scripture =
        context.trList(TranslationKeys.generateStudyScriptureSuggestions);
    final topics =
        context.trList(TranslationKeys.generateStudyTopicSuggestions);
    final chips = [...scripture.take(1), ...topics.take(2)];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final chip in chips)
          _SuggestionChip(label: chip, onTap: () => _fill(chip)),
      ],
    );
  }

  Widget _verseOfDay() {
    return BlocBuilder<DailyVerseBloc, DailyVerseState>(
      builder: (context, state) {
        if (state is! VerseDataStateMixin) return const SizedBox.shrink();
        final verse = (state as VerseDataStateMixin).verse;
        final language = switch (_language) {
          StudyLanguage.english => VerseLanguage.english,
          StudyLanguage.hindi => VerseLanguage.hindi,
          StudyLanguage.malayalam => VerseLanguage.malayalam,
        };
        final reference = verse.getReferenceText(language);
        if (reference.trim().isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: VerseOfDayRow(
            reference: reference,
            verseText: verse.getVerseText(language),
            onTap: () => _launchVerse(reference),
          ),
        );
      },
    );
  }

  /// "Choose depth" with the "All 5 ›" link to the full chooser.
  Widget _depthHeader() {
    final palette = ReaderPalette.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            context.tr(TranslationKeys.generateSimpleChooseDepth),
            style: AppFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: palette.text,
            ),
          ),
        ),
        TextButton(
          key: const Key('generate_depth_all'),
          onPressed: _openAllDepths,
          style: TextButton.styleFrom(
            foregroundColor: palette.muted,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(44, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr(TranslationKeys.generateSimpleAllDepths),
                style: AppFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: palette.muted,
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 16, color: palette.muted),
            ],
          ),
        ),
      ],
    );
  }

  Widget _generateButton(bool inputValid) {
    final palette = ReaderPalette.of(context);
    final active = inputValid && !_launching;
    final fill = active
        ? palette.ctaFill
        : (palette.isDark
            ? Colors.white.withValues(alpha: 0.10)
            : palette.text.withValues(alpha: 0.08));
    final ink = active
        ? palette.ctaInk
        : (palette.isDark ? Colors.white.withValues(alpha: 0.45) : palette.dim);
    return Semantics(
      button: true,
      enabled: active,
      child: Material(
        color: fill,
        shape: const StadiumBorder(),
        child: InkWell(
          key: const Key('generate_simple_button'),
          onTap: active ? _generate : null,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _buttonHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_launching) ...[
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(ink),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      context.tr(TranslationKeys.generateSimpleGenerate),
                      textAlign: TextAlign.center,
                      style: AppFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact suggestion pill over the photo header.
class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final ink = GenerateHeroInk.of(context);
    return Material(
      key: const Key('suggestion_chip'),
      color:
          palette.isDark ? Colors.white.withValues(alpha: 0.14) : palette.card,
      shape: palette.isDark
          ? const StadiumBorder()
          : StadiumBorder(side: BorderSide(color: palette.outline)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              label,
              style: AppFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: palette.isDark ? ink.text : palette.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
