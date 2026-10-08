import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/widgets/upgrade_dialog.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart'
    as auth_states;
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/public_fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/discover/discover_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/discover/discover_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/discover/discover_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_buttons.dart';
import 'package:disciplefy_bible_study/shared/widgets/photo_wash.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_top_bars.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_card_parts.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/showcase_keys.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/walkthrough_tooltip.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

class CommunityTabScreen extends StatefulWidget {
  const CommunityTabScreen({super.key});

  @override
  State<CommunityTabScreen> createState() => _CommunityTabScreenState();
}

class _CommunityTabScreenState extends State<CommunityTabScreen> {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<FellowshipListBloc>(
          create: (_) => sl<FellowshipListBloc>()
            ..add(const FellowshipListLoadRequested()),
        ),
        BlocProvider<DiscoverBloc>(
          create: (_) => sl<DiscoverBloc>(),
        ),
      ],
      child: ShowCaseWidget(
        onFinish: () =>
            sl<WalkthroughRepository>().markSeen(WalkthroughScreen.community),
        builder: (context) => const CommunityTabContent(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inner content
// ---------------------------------------------------------------------------

/// The Community tab below its bloc providers: photo-wash header, large
/// title with Join/Create actions, My fellowships / Discover tabs.
///
/// Public so widget tests can mount it with their own blocs.
@visibleForTesting
class CommunityTabContent extends StatefulWidget {
  const CommunityTabContent({super.key});

  @override
  State<CommunityTabContent> createState() => _CommunityTabContentState();
}

class _CommunityTabContentState extends State<CommunityTabContent> {
  int _selectedTab = 0; // 0 = My Fellowships, 1 = Discover

  GoRouter? _router;
  bool _wasInFellowshipDetail = false;

  @override
  void initState() {
    super.initState();
    _triggerWalkthroughIfNeeded();
  }

  VoidCallback get _onNext => () => ShowCaseWidget.of(context).next();

  Future<void> _triggerWalkthroughIfNeeded() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final repo = sl<WalkthroughRepository>();
      if (await repo.hasSeen(WalkthroughScreen.community)) return;

      // Always show both steps: tabs (step 1) + join with a code (step 2).
      final keys = <GlobalKey>[
        ShowcaseKeys.communityTabs,
        ShowcaseKeys.communityFab,
      ];

      // Wait one frame so all tooltip widgets are in the tree before
      // showcaseview tries to resolve their GlobalKeys.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ShowCaseWidget.of(context).startShowCase(keys);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-attach listener when the router changes (should only happen once).
    final router = GoRouter.maybeOf(context);
    if (_router != router) {
      _router?.routerDelegate.removeListener(_onRouteChange);
      _router = router;
      _router?.routerDelegate.addListener(_onRouteChange);
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChange);
    super.dispose();
  }

  void _onRouteChange() {
    if (!mounted) return;
    final location = _router?.state.uri.toString() ?? '';
    final inDetail = location.startsWith('/community/') &&
        !location.startsWith('/community/join') &&
        !location.startsWith('/community/create');
    if (_wasInFellowshipDetail && !inDetail && location == '/community') {
      // Returned from a fellowship detail — refresh the list.
      context
          .read<FellowshipListBloc>()
          .add(const FellowshipListLoadRequested());
    }
    _wasInFellowshipDetail = inDetail;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      body: PhotoWash(
        image: PhotoWash.communityTabImage,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CommunityLargeTitleBar(
                title: l10n.communityTitle,
                actions: [_buildTopActions(context)],
              ),

              // ── Tabs ─────────────────────────────────────────────────────
              WalkthroughTooltip(
                showcaseKey: ShowcaseKeys.communityTabs,
                title: l10n.walkthroughCommunityTabsTitle,
                description: l10n.walkthroughCommunityTabsDesc,
                screen: WalkthroughScreen.community,
                stepNumber: 1,
                totalSteps: 2,
                tooltipPosition: TooltipPosition.bottom,
                onNext: _onNext,
                child: CommunityUnderlineTabs(
                  labels: [
                    l10n.communityMyFellowships,
                    context.tr(TranslationKeys.communitySharedDiscoverTab),
                  ],
                  selected: _selectedTab,
                  // _DiscoverTab loads itself on mount, so switching tabs from
                  // anywhere (tabs or the empty-state CTA) always triggers a
                  // fetch.
                  onChanged: (i) => setState(() => _selectedTab = i),
                ),
              ),
              const SizedBox(height: 12),

              // ── Body ─────────────────────────────────────────────────────
              Expanded(
                child: _selectedTab == 0
                    ? _MyFellowshipsTab(
                        onJoinPressed: _onJoinPressed,
                        onDiscover: () => setState(() => _selectedTab = 1),
                        onCreatePressed: _onCreatePressed,
                      )
                    : const _DiscoverTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Join (key) — the one way in by code — and Create (+) actions. Create is hidden by the feature flag,
  /// or shown with a lock badge and an upsell when the plan lacks it.
  Widget _buildTopActions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<TokenBloc, TokenState>(
      builder: (context, _) =>
          BlocBuilder<FellowshipListBloc, FellowshipListState>(
        buildWhen: (prev, curr) =>
            prev.fellowships != curr.fellowships || prev.status != curr.status,
        builder: (context, listState) {
          final canCreate = _canCreateFellowship(context, listState);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              WalkthroughTooltip(
                showcaseKey: ShowcaseKeys.communityFab,
                title: l10n.walkthroughCommunityFabTitle,
                description: l10n.walkthroughCommunityFabDesc,
                screen: WalkthroughScreen.community,
                stepNumber: 2,
                totalSteps: 2,
                onNext: _onNext,
                child: CommunityIconAction(
                  icon: Icons.key_outlined,
                  tooltip:
                      context.tr(TranslationKeys.communitySharedJoinWithCode),
                  onPressed: _onJoinPressed,
                ),
              ),
              if (!_hideCreateFellowship(context))
                CommunityIconAction(
                  icon: Icons.add_rounded,
                  badge: canCreate ? null : Icons.lock_rounded,
                  tooltip: canCreate
                      ? l10n.createFellowshipTitle
                      : context.tr(TranslationKeys.communitySharedCreateLocked),
                  onPressed: () {
                    if (!canCreate) {
                      // Shown but not entitled: offer the upgrade rather than
                      // hiding the capability, so there is something to
                      // upgrade towards.
                      _showCreateFellowshipUpsell(context);
                      return;
                    }
                    _onCreatePressed();
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _onJoinPressed() async {
    final joined = await context.push<bool>(AppRoutes.communityJoin);
    if (joined == true && mounted) {
      context
          .read<FellowshipListBloc>()
          .add(const FellowshipListLoadRequested());
    }
  }

  Future<void> _onCreatePressed() async {
    final created = await context.push<bool>(AppRoutes.communityCreate);
    if (created == true && mounted) {
      context
          .read<FellowshipListBloc>()
          .add(const FellowshipListLoadRequested());
    }
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

Widget _spinner(BuildContext context) => Center(
      child: CircularProgressIndicator(
        valueColor:
            AlwaysStoppedAnimation<Color>(ReaderPalette.of(context).accentIcon),
      ),
    );

/// Signed-in user's id, for "(you)" on fellowships they mentor.
String? _currentUserId(BuildContext context) {
  try {
    final state = context.read<AuthBloc>().state;
    if (state is auth_states.AuthenticatedState) return state.userId;
  } catch (_) {}
  return null;
}

// ---------------------------------------------------------------------------
// My Fellowships tab
// ---------------------------------------------------------------------------

class _MyFellowshipsTab extends StatelessWidget {
  final Future<void> Function() onJoinPressed;
  final VoidCallback onDiscover;
  final Future<void> Function() onCreatePressed;

  const _MyFellowshipsTab({
    required this.onJoinPressed,
    required this.onDiscover,
    required this.onCreatePressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<TokenBloc, TokenState>(
      builder: (context, _) =>
          BlocConsumer<FellowshipListBloc, FellowshipListState>(
        listenWhen: (previous, current) =>
            previous.joinStatus != current.joinStatus,
        listener: (context, state) {
          if (state.joinStatus == FellowshipJoinStatus.success) {
            showAppSnackBar(context, l10n.communityJoinedSuccess,
                tone: AppSnackTone.success);
          } else if (state.joinStatus == FellowshipJoinStatus.failure) {
            showAppSnackBar(
                context, state.joinError ?? l10n.communityJoinFailed,
                tone: AppSnackTone.error);
          }
        },
        builder: (context, state) {
          switch (state.status) {
            case FellowshipListStatus.initial:
            case FellowshipListStatus.loading:
              return _spinner(context);

            case FellowshipListStatus.failure:
              return _ErrorState(
                message: state.errorMessage ?? l10n.communityJoinFailed,
                onRetry: () => context
                    .read<FellowshipListBloc>()
                    .add(const FellowshipListLoadRequested()),
              );

            case FellowshipListStatus.success:
              if (state.fellowships.isEmpty) {
                return _EmptyState(
                  onDiscover: onDiscover,
                  onCreateFellowship: onCreatePressed,
                  canCreate: _canCreateFellowship(context, state),
                );
              }
              return _FellowshipList(
                fellowships: state.fellowships,
                onJoinPressed: onJoinPressed,
              );
          }
        },
      ),
    );
  }
}

class _FellowshipList extends StatelessWidget {
  final List<FellowshipEntity> fellowships;
  final Future<void> Function() onJoinPressed;

  const _FellowshipList({
    required this.fellowships,
    required this.onJoinPressed,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUserId(context);
    // "Join a fellowship" floats above the dock, as in the design; the key
    // icon in the header stays as the second way in.
    return Stack(
      children: [
        Positioned.fill(child: _list(context, currentUserId)),
        PositionedDirectional(
          end: 20,
          // The shell reports the dock as bottom padding.
          bottom: 24 + MediaQuery.paddingOf(context).bottom,
          child: CommunityCtaPill(
            key: const Key('community_join_fab'),
            large: true,
            icon: Icons.key_outlined,
            label: context.tr(TranslationKeys.communitySharedJoinFellowship),
            onPressed: onJoinPressed,
          ),
        ),
      ],
    );
  }

  Widget _list(BuildContext context, String? currentUserId) {
    return RefreshIndicator(
      color: ReaderPalette.of(context).accentIcon,
      onRefresh: () async => context
          .read<FellowshipListBloc>()
          .add(const FellowshipListLoadRequested()),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        // Clears the dock (the bottom padding) and the join pill above it.
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, 80 + MediaQuery.paddingOf(context).bottom),
        itemCount: fellowships.length,
        itemBuilder: (context, index) {
          final fellowship = fellowships[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MyFellowshipCard(
              fellowship: fellowship,
              currentUserId: currentUserId,
              onTap: () => context.go(
                '/community/${fellowship.id}',
                extra: fellowship,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A fellowship the user belongs to: name (+ Official), mentor and member
/// count, and the current study with its progress.
class MyFellowshipCard extends StatelessWidget {
  final FellowshipEntity fellowship;
  final String? currentUserId;
  final VoidCallback onTap;

  const MyFellowshipCard({
    super.key,
    required this.fellowship,
    required this.onTap,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return FellowshipCardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FellowshipCardTitle(
            name: fellowship.name,
            isOfficial: fellowship.isOfficial,
          ),
          const SizedBox(height: 14),
          FellowshipMentorRow(
            mentor: FellowshipMentorInfo.forFellowship(
              fellowship,
              currentUserId: currentUserId,
            ),
            memberCount: fellowship.memberCount,
          ),
          if (fellowship.currentStudy != null) ...[
            const SizedBox(height: 10),
            FellowshipCurrentStudyRow(study: fellowship.currentStudy!),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Discover tab
// ---------------------------------------------------------------------------

class _DiscoverTab extends StatefulWidget {
  const _DiscoverTab();

  @override
  State<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<_DiscoverTab> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Load on mount so the tab is never stuck on the initial (spinner) state,
    // regardless of how the user reached Discover.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<DiscoverBloc>();
      if (bloc.state.status != DiscoverStatus.initial) return;
      // Open on the app language so the first groups shown are ones the
      // user can read; the "All" chip still shows every language.
      bloc.add(DiscoverLoadRequested(language: _appLanguageCode()));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {}); // Rebuild so the clear button shows/hides
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final bloc = context.read<DiscoverBloc>();
      bloc.add(DiscoverLoadRequested(
        language: bloc.state.language,
        search: value.trim().isEmpty ? null : value.trim(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return BlocConsumer<DiscoverBloc, DiscoverState>(
      listenWhen: (prev, curr) =>
          (curr.justJoinedName != null &&
              prev.justJoinedName != curr.justJoinedName) ||
          (curr.errorMessage != null && prev.errorMessage != curr.errorMessage),
      listener: (context, state) {
        if (state.justJoinedName != null) {
          showAppSnackBar(
            context,
            context.tr(TranslationKeys.communityJoined,
                {'name': state.justJoinedName!}),
            tone: AppSnackTone.success,
          );
          final joinedId = state.justJoinedId;
          context.read<DiscoverBloc>().add(const DiscoverJoinAcknowledged());
          context
              .read<FellowshipListBloc>()
              .add(const FellowshipListLoadRequested());
          // Take the new member straight into the group they joined.
          if (joinedId != null) context.push('/community/$joinedId');
        } else if (state.errorMessage != null) {
          showAppSnackBar(context, state.errorMessage!,
              tone: AppSnackTone.error);
        }
      },
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: AppFonts.inter(fontSize: 14, color: palette.text),
                decoration: InputDecoration(
                  isDense: true,
                  hintText:
                      context.tr(TranslationKeys.communitySharedSearchHint),
                  hintStyle: AppFonts.inter(fontSize: 14, color: palette.muted),
                  hintMaxLines: 2,
                  prefixIcon:
                      Icon(Icons.search_rounded, size: 16, color: palette.dim),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .deleteButtonTooltip,
                          icon: Icon(Icons.close_rounded,
                              size: 20, color: palette.muted),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: palette.card,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: palette.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: palette.hairline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: palette.accentIcon),
                  ),
                ),
              ),
            ),
            _LanguageFilterChips(
              activeLanguage: state.language,
              onChanged: (lang) => context.read<DiscoverBloc>().add(
                    DiscoverLoadRequested(
                      language: lang,
                      search: state.search,
                    ),
                  ),
            ),
            const SizedBox(height: 6),
            Expanded(child: _DiscoverBody(state: state)),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final VoidCallback onDiscover;
  final Future<void> Function() onCreateFellowship;
  final bool canCreate;

  const _EmptyState({
    required this.onDiscover,
    required this.onCreateFellowship,
    required this.canCreate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            28, 8, 28, 24 + MediaQuery.paddingOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: palette.accentIcon.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.groups_2_outlined,
                    size: 44, color: palette.accentIcon),
              ),
              const SizedBox(height: 22),
              Text(
                l10n.communityEmptyTitle,
                style: AppFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                l10n.communityEmptyDescription,
                style: AppFonts.inter(
                  fontSize: 15,
                  color: palette.muted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              // Joining by code is the key icon in the title bar, so it is
              // not repeated here.
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: CommunityRaisedPill(
                  label: l10n.communityDiscover,
                  icon: Icons.explore_outlined,
                  onPressed: onDiscover,
                ),
              ),
              if (canCreate) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: CommunityRaisedPill(
                    label: l10n.createFellowshipTitle,
                    icon: Icons.add_rounded,
                    onPressed: onCreateFellowship,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    bool isOffline = false;
    try {
      isOffline = context.read<ConnectivityBloc>().state is ConnectivityOffline;
    } catch (_) {}
    final tint = isOffline ? palette.muted : context.appError;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                isOffline
                    ? Icons.wifi_off_rounded
                    : Icons.error_outline_rounded,
                size: 34,
                color: tint,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isOffline
                  ? context.tr(TranslationKeys.communitySharedOfflineTitle)
                  : l10n.communityLoadError,
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOffline
                  ? context.tr(TranslationKeys.communitySharedOfflineBody)
                  : context.tr(TranslationKeys.communitySharedLoadErrorBody),
              style: AppFonts.inter(fontSize: 14.5, color: palette.muted),
              textAlign: TextAlign.center,
            ),
            if (!isOffline) ...[
              const SizedBox(height: 24),
              CommunityRaisedPill(
                label: l10n.communityRetry,
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Language filter chips
// ---------------------------------------------------------------------------

class _LanguageFilterChips extends StatelessWidget {
  final String? activeLanguage;
  final ValueChanged<String?> onChanged;

  const _LanguageFilterChips({
    required this.activeLanguage,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filters = <MapEntry<String?, String>>[
      MapEntry(null, l10n.discoverFilterAll),
      MapEntry('en', l10n.discoverFilterEnglish),
      MapEntry('hi', l10n.discoverFilterHindi),
      MapEntry('ml', l10n.discoverFilterMalayalam),
    ];
    // A plain scrolling row (not a lazy list) so every filter is built and
    // reachable, whatever the label widths in hi/ml.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          for (var i = 0; i < filters.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            CommunityRaisedPill(
              label: filters[i].value,
              selected: activeLanguage == filters[i].key,
              onPressed: () => onChanged(filters[i].key),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Discover body
// ---------------------------------------------------------------------------

class _DiscoverBody extends StatefulWidget {
  final DiscoverState state;

  const _DiscoverBody({required this.state});

  @override
  State<_DiscoverBody> createState() => _DiscoverBodyState();
}

class _DiscoverBodyState extends State<_DiscoverBody> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    if (current >= maxScroll - 200) {
      context.read<DiscoverBloc>().add(const DiscoverLoadMoreRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final l10n = AppLocalizations.of(context)!;
    switch (state.status) {
      case DiscoverStatus.initial:
      case DiscoverStatus.loading:
        return _spinner(context);
      case DiscoverStatus.failure:
        return _ErrorState(
          message: state.errorMessage ?? l10n.communityLoadError,
          onRetry: () => context
              .read<DiscoverBloc>()
              .add(DiscoverLoadRequested(language: state.language)),
        );
      case DiscoverStatus.success:
        if (state.fellowships.isEmpty) {
          return _DiscoverEmptyState(
            hasLanguageFilter: state.language != null,
            onShowAll: () =>
                context.read<DiscoverBloc>().add(const DiscoverLoadRequested()),
          );
        }
        return RefreshIndicator(
          color: ReaderPalette.of(context).accentIcon,
          onRefresh: () async => context
              .read<DiscoverBloc>()
              .add(DiscoverLoadRequested(language: state.language)),
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, 100 + MediaQuery.paddingOf(context).bottom),
            itemCount: state.fellowships.length + (state.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == state.fellowships.length) {
                // Bottom loading indicator — shown while fetching next page.
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: _spinner(context),
                );
              }
              final f = state.fellowships[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DiscoverFellowshipCard(
                  fellowship: f,
                  isJoining: state.joiningIds.contains(f.id),
                  onJoin: () => context.read<DiscoverBloc>().add(
                        DiscoverJoinRequested(
                          fellowshipId: f.id,
                          fellowshipName: f.name,
                        ),
                      ),
                ),
              );
            },
          ),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Discover empty state
// ---------------------------------------------------------------------------

class _DiscoverEmptyState extends StatelessWidget {
  final bool hasLanguageFilter;
  final VoidCallback onShowAll;

  const _DiscoverEmptyState({
    required this.hasLanguageFilter,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_off_outlined, size: 56, color: palette.dim),
            const SizedBox(height: 16),
            Text(
              l10n.discoverEmpty,
              style: AppFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: palette.muted,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasLanguageFilter) ...[
              const SizedBox(height: 16),
              CommunityRaisedPill(
                label: l10n.discoverEmptyShowAll,
                onPressed: onShowAll,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Public fellowship card
// ---------------------------------------------------------------------------

/// A public fellowship on Discover: name (+ Official), description, current
/// study, capacity when limited, language chip, mentor and members, and the
/// Join (or Full) action.
class DiscoverFellowshipCard extends StatelessWidget {
  final PublicFellowshipEntity fellowship;
  final bool isJoining;
  final VoidCallback onJoin;

  const DiscoverFellowshipCard({
    super.key,
    required this.fellowship,
    required this.isJoining,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final isFull = !fellowship.isUnlimited &&
        fellowship.memberCount >= fellowship.maxMembers!;
    final description = fellowship.description?.trim();
    final study = fellowship.currentStudyTitle?.trim();
    final muted =
        AppFonts.inter(fontSize: 12.5, color: palette.muted, height: 1.4);

    final mentorRow = FellowshipMentorRow(
      leading: FellowshipLanguageChip(language: fellowship.language),
      mentor: FellowshipMentorInfo.forPublicFellowship(fellowship),
      memberCount: fellowship.memberCount,
      avatarRadius: 11,
    );
    final action = _JoinButton(
      isFull: isFull,
      isJoining: isJoining,
      onJoin: onJoin,
    );

    return FellowshipCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FellowshipCardTitle(
            name: fellowship.name,
            isOfficial: fellowship.isOfficial,
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.inter(
                fontSize: 13,
                color: palette.muted,
                height: 1.45,
              ),
            ),
          ],
          if (study != null && study.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(Icons.menu_book_outlined,
                      size: 16, color: palette.gold),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(study, style: muted)),
              ],
            ),
          ],
          if (!fellowship.isUnlimited) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.people_outline_rounded,
                    size: 16, color: palette.muted),
                const SizedBox(width: 8),
                Text(
                  '${fellowship.memberCount} / ${fellowship.maxMembers}',
                  style: muted,
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, box) {
              // Narrow cards: the action drops under the mentor line so
              // neither is squeezed into a sliver.
              if (box.maxWidth < 300) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    mentorRow,
                    const SizedBox(height: 12),
                    Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: action),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: mentorRow),
                  const SizedBox(width: 12),
                  action,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Join button
// ---------------------------------------------------------------------------

class _JoinButton extends StatelessWidget {
  final bool isFull;
  final bool isJoining;
  final VoidCallback onJoin;

  const _JoinButton({
    required this.isFull,
    required this.isJoining,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);

    if (isFull) {
      return Container(
        constraints: const BoxConstraints(minHeight: 32),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.outline),
        ),
        child: Text(
          l10n.discoverFull,
          style: AppFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: palette.muted,
          ),
        ),
      );
    }

    return CommunityCtaPill(
      label: l10n.discoverJoinButton,
      loading: isJoining,
      onPressed: onJoin,
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Current plan code from the one plan source (TokenBloc), defaulting to free
/// while it is unknown. The subscription bloc only carries the plan in one of
/// its many states, which made the paywall read "Free" for a Standard user.
String _currentPlan(BuildContext context) {
  try {
    return currentPlanCode(context.read<TokenBloc>().state);
  } catch (_) {
    return 'free';
  }
}

/// Whether the flag says to hide Create Fellowship entirely.
///
/// `display_mode` on the `create_fellowship` flag decides this: 'lock' keeps
/// the item visible for an upsell, 'hide' removes it, and disabling the flag
/// removes it for everyone. Backend-controlled so entitlement can change
/// without an app release.
bool _hideCreateFellowship(BuildContext context) {
  try {
    return sl<SystemConfigService>()
        .shouldHideFeature('create_fellowship', _currentPlan(context));
  } catch (_) {
    return false; // Config unavailable — fall back to showing it.
  }
}

/// Upgrade sheet for users whose plan does not include creating a fellowship.
void _showCreateFellowshipUpsell(BuildContext context) {
  showModalBottomSheet(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => UpgradeDialog(
      featureKey: 'create_fellowship',
      currentPlan: _currentPlan(context),
      requiredPlans: const ['plus', 'premium'],
    ),
  );
}

/// The app language code ('en', 'hi', 'ml'), or null (all languages) when
/// the translation service is not available.
String? _appLanguageCode() {
  if (!sl.isRegistered<TranslationService>()) return null;
  return sl<TranslationService>().currentLanguage.code;
}

bool _canCreateFellowship(BuildContext context, FellowshipListState listState) {
  try {
    final authState = context.read<AuthBloc>().state;
    if (authState is auth_states.AuthenticatedState && authState.isAdmin) {
      return true;
    }
  } catch (_) {}
  if (listState.fellowships.any((f) => f.userRole == 'mentor')) return true;
  final plan = _currentPlan(context);
  return plan == 'plus' || plan == 'premium';
}
