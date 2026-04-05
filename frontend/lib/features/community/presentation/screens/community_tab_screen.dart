import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart'
    as auth_states;
import '../../../../features/subscription/presentation/bloc/subscription_bloc.dart';
import '../../../../features/subscription/presentation/bloc/subscription_state.dart';
import '../../domain/entities/fellowship_entity.dart';
import '../../domain/entities/public_fellowship_entity.dart';
import '../bloc/discover/discover_bloc.dart';
import '../bloc/discover/discover_event.dart';
import '../bloc/discover/discover_state.dart';
import '../bloc/fellowship_list/fellowship_list_bloc.dart';
import '../bloc/fellowship_list/fellowship_list_event.dart';
import '../bloc/fellowship_list/fellowship_list_state.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../../core/connectivity/connectivity_bloc.dart';
import '../../../walkthrough/domain/walkthrough_repository.dart';
import '../../../walkthrough/domain/walkthrough_screen.dart';
import '../../../walkthrough/presentation/showcase_keys.dart';
import '../../../walkthrough/presentation/walkthrough_tooltip.dart';

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
        builder: (context) => const _CommunityTabContent(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inner content
// ---------------------------------------------------------------------------

class _CommunityTabContent extends StatefulWidget {
  const _CommunityTabContent();

  @override
  State<_CommunityTabContent> createState() => _CommunityTabContentState();
}

class _CommunityTabContentState extends State<_CommunityTabContent> {
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

      // Always show both steps: tabs (step 1) + FAB/join (step 2).
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
    final router = GoRouter.of(context);
    if (_router != router) {
      _router?.routerDelegate.removeListener(_onRouteChange);
      _router = router;
      _router!.routerDelegate.addListener(_onRouteChange);
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
    return Scaffold(
      backgroundColor: context.appScaffold,
      appBar: AppBar(
        backgroundColor: context.appScaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          l10n.communityTitle,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
        actions: [
          BlocBuilder<SubscriptionBloc, SubscriptionState>(
            builder: (context, _) =>
                BlocBuilder<FellowshipListBloc, FellowshipListState>(
              buildWhen: (prev, curr) =>
                  prev.fellowships != curr.fellowships ||
                  prev.status != curr.status,
              builder: (context, listState) {
                final canCreate = _canCreateFellowship(context, listState);
                return PopupMenuButton<_CommunityAction>(
                  icon: Icon(
                    Icons.more_vert,
                    color: context.appTextPrimary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  color: context.appSurface,
                  elevation: 4,
                  onSelected: (action) async {
                    if (action == _CommunityAction.join) {
                      final joined =
                          await context.push<bool>(AppRoutes.communityJoin);
                      if (joined == true && context.mounted) {
                        context
                            .read<FellowshipListBloc>()
                            .add(const FellowshipListLoadRequested());
                      }
                    } else if (action == _CommunityAction.create) {
                      final created =
                          await context.push<bool>(AppRoutes.communityCreate);
                      if (created == true && context.mounted) {
                        context
                            .read<FellowshipListBloc>()
                            .add(const FellowshipListLoadRequested());
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _CommunityAction.join,
                      child: Row(
                        children: [
                          Icon(Icons.vpn_key_outlined,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Text(
                            l10n.communityJoinButton,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: context.appTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canCreate)
                      PopupMenuItem(
                        value: _CommunityAction.create,
                        child: Row(
                          children: [
                            Icon(Icons.groups_2_rounded,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 12),
                            Text(
                              l10n.createFellowshipTitle,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: context.appTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Pill tabs ────────────────────────────────────────────────────
          // Padding is outside the tooltip so only the pill bar is highlighted.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: WalkthroughTooltip(
              showcaseKey: ShowcaseKeys.communityTabs,
              title: l10n.walkthroughCommunityTabsTitle,
              description: l10n.walkthroughCommunityTabsDesc,
              screen: WalkthroughScreen.community,
              stepNumber: 1,
              totalSteps: 2,
              tooltipPosition: TooltipPosition.bottom,
              onNext: _onNext,
              child: _PillTabs(
                selected: _selectedTab,
                onChanged: (i) {
                  setState(() => _selectedTab = i);
                  if (i == 1) {
                    final discoverBloc = context.read<DiscoverBloc>();
                    if (discoverBloc.state.status == DiscoverStatus.initial) {
                      // Default the language filter to the user's current app
                      // locale, bounded to the set of supported fellowship languages.
                      final localeCode =
                          AppLocalizations.of(context)!.locale.languageCode;
                      final initialLang =
                          ['en', 'hi', 'ml'].contains(localeCode)
                              ? localeCode
                              : null;
                      discoverBloc
                          .add(DiscoverLoadRequested(language: initialLang));
                    }
                  }
                },
                tabs: [
                  Text(l10n.communityMyFellowships),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.public_rounded),
                      SizedBox(width: 5),
                      Text('Discover'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          Expanded(
            child: _selectedTab == 0
                ? _MyFellowshipsTab(
                    onJoinPressed: _onJoinPressed,
                    onDiscover: () => setState(() => _selectedTab = 1),
                    onCreatePressed: _onCreatePressed,
                  )
                : _DiscoverTab(),
          ),
        ],
      ),
      floatingActionButton: _selectedTab == 0
          ? WalkthroughTooltip(
              showcaseKey: ShowcaseKeys.communityFab,
              title: AppLocalizations.of(context)!.walkthroughCommunityFabTitle,
              description:
                  AppLocalizations.of(context)!.walkthroughCommunityFabDesc,
              screen: WalkthroughScreen.community,
              stepNumber: 2,
              totalSteps: 2,
              onNext: _onNext,
              child: FloatingActionButton.extended(
                onPressed: _onJoinPressed,
                backgroundColor: context.appInteractive,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.group_add_rounded),
                label: Text(
                  l10n.communityJoinFellowship,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          : null,
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
// Pill tabs
// ---------------------------------------------------------------------------

class _PillTabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  final List<Widget> tabs;

  const _PillTabs({
    required this.selected,
    required this.onChanged,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.appSurfaceVariant,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color:
                      isSelected ? context.appInteractive : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: DefaultTextStyle(
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : context.appTextSecondary,
                  ),
                  child: IconTheme(
                    data: IconThemeData(
                      size: 15,
                      color:
                          isSelected ? Colors.white : context.appTextSecondary,
                    ),
                    child: tabs[i],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
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

  bool _computeCanCreate(BuildContext context, FellowshipListState listState) {
    return _canCreateFellowship(context, listState);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<SubscriptionBloc, SubscriptionState>(
      builder: (context, _) =>
          BlocConsumer<FellowshipListBloc, FellowshipListState>(
        listenWhen: (previous, current) =>
            previous.joinStatus != current.joinStatus,
        listener: (context, state) {
          if (state.joinStatus == FellowshipJoinStatus.success) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(l10n.communityJoinedSuccess),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ));
          } else if (state.joinStatus == FellowshipJoinStatus.failure) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(state.joinError ?? l10n.communityJoinFailed),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ));
          }
        },
        builder: (context, state) {
          switch (state.status) {
            case FellowshipListStatus.initial:
            case FellowshipListStatus.loading:
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary),
                ),
              );

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
                  onJoin: onJoinPressed,
                  onDiscover: onDiscover,
                  onCreateFellowship: onCreatePressed,
                  canCreate: _computeCanCreate(context, state),
                );
              }
              return _FellowshipList(
                fellowships: state.fellowships,
              );
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fellowship list
// ---------------------------------------------------------------------------

class _FellowshipList extends StatelessWidget {
  final List<FellowshipEntity> fellowships;

  const _FellowshipList({required this.fellowships});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () async => context
          .read<FellowshipListBloc>()
          .add(const FellowshipListLoadRequested()),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: fellowships.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _FellowshipCard(
              fellowship: fellowships[index],
              onTap: () => context.go(
                '/community/${fellowships[index].id}',
                extra: fellowships[index],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fellowship card — matches wireframe design
// ---------------------------------------------------------------------------

class _FellowshipCard extends StatelessWidget {
  final FellowshipEntity fellowship;
  final VoidCallback onTap;

  const _FellowshipCard({required this.fellowship, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMentor = fellowship.userRole.toLowerCase() == 'mentor';
    final initials = _initials(fellowship.name);
    final avatarColor = _avatarColor(fellowship.name);

    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(
            children: [
              // ── Avatar ──────────────────────────────────────────────────
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: avatarColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // ── Content ─────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            fellowship.name,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: context.appTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (fellowship.isPublic) ...[
                          const SizedBox(width: 5),
                          Icon(Icons.public_rounded,
                              size: 14, color: context.appTextTertiary),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Subtitle: role badge + member count
                    Row(
                      children: [
                        _RolePill(isMentor: isMentor),
                        const SizedBox(width: 8),
                        Icon(Icons.people_outline_rounded,
                            size: 13, color: context.appTextTertiary),
                        const SizedBox(width: 3),
                        Text(
                          '${fellowship.memberCount} ${l10n.communityMembers}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: context.appTextTertiary,
                          ),
                        ),
                      ],
                    ),

                    // Mentor name
                    if (fellowship.mentorName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded,
                              size: 13, color: context.appTextTertiary),
                          const SizedBox(width: 3),
                          Text(
                            fellowship.mentorName!,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: context.appTextTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],

                    // Study chip (if active)
                    if (fellowship.currentStudy != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _StudyChip(
                            title: fellowship.currentStudy!.learningPathTitle,
                            guideIndex:
                                fellowship.currentStudy!.currentGuideIndex,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: context.appTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF6A4FB6), // brand purple
      Color(0xFF3B82F6), // blue
      Color(0xFF10B981), // green
      Color(0xFFF59E0B), // amber
      Color(0xFFEF4444), // red
      Color(0xFF8B5CF6), // violet
      Color(0xFF06B6D4), // cyan
      Color(0xFFEC4899), // pink
    ];
    final hash = name.codeUnits.fold(0, (a, b) => a + b);
    return colors[hash % colors.length];
  }
}

// ---------------------------------------------------------------------------
// Role pill
// ---------------------------------------------------------------------------

class _RolePill extends StatelessWidget {
  final bool isMentor;

  const _RolePill({required this.isMentor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isMentor
            ? AppColors.brandHighlight
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: isMentor
            ? Border.all(color: AppColors.brandHighlightDark.withOpacity(0.4))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMentor ? Icons.star_rounded : Icons.person_rounded,
            size: 11,
            color: isMentor
                ? AppColors.brandHighlightDark
                : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 3),
          Text(
            isMentor ? 'Mentor' : 'Member',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isMentor
                  ? AppColors.brandHighlightDark
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Study chip
// ---------------------------------------------------------------------------

class _StudyChip extends StatelessWidget {
  final String? title;
  final int guideIndex;

  const _StudyChip({this.title, required this.guideIndex});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipColor = isDark
        ? AppColors.brandPrimaryLight
        : Theme.of(context).colorScheme.primary;
    final label =
        title != null && title!.isNotEmpty ? title! : 'Guide ${guideIndex + 1}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: isDark ? 0.22 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: isDark ? 0.50 : 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_rounded, size: 12, color: chipColor),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: chipColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Discover tab
// ---------------------------------------------------------------------------

class _DiscoverTab extends StatefulWidget {
  @override
  State<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<_DiscoverTab> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {}); // Rebuild so suffixIcon clear button shows/hides
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
    return BlocConsumer<DiscoverBloc, DiscoverState>(
      listenWhen: (prev, curr) =>
          (curr.justJoinedName != null &&
              prev.justJoinedName != curr.justJoinedName) ||
          (curr.errorMessage != null && prev.errorMessage != curr.errorMessage),
      listener: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        if (state.justJoinedName != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(l10n.discoverJoinedSnackbar(state.justJoinedName!)),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ));
          context.read<DiscoverBloc>().add(const DiscoverJoinAcknowledged());
          context
              .read<FellowshipListBloc>()
              .add(const FellowshipListLoadRequested());
        } else if (state.errorMessage != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ));
        }
      },
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: context.appTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search fellowships…',
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: context.appTextTertiary,
                  ),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 20, color: context.appTextTertiary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 18, color: context.appTextTertiary),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: context.appInputFill,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
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
  final Future<void> Function() onJoin;
  final VoidCallback onDiscover;
  final Future<void> Function() onCreateFellowship;
  final bool canCreate;

  const _EmptyState({
    required this.onJoin,
    required this.onDiscover,
    required this.onCreateFellowship,
    required this.canCreate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.groups_2_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.communityEmptyTitle,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.communityEmptyDescription,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: context.appTextSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onJoin,
                  borderRadius: BorderRadius.circular(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.group_add_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        l10n.communityJoinFellowship,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: onDiscover,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: Theme.of(context).colorScheme.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: Icon(Icons.explore_outlined,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              label: Text(
                l10n.communityDiscover,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          if (canCreate) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: onCreateFellowship,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: Theme.of(context).colorScheme.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: Icon(Icons.groups_2_rounded,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                label: Text(
                  l10n.createFellowshipTitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
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
    final isOffline =
        context.read<ConnectivityBloc>().state is ConnectivityOffline;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isOffline
                    ? theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isOffline
                    ? Icons.wifi_off_rounded
                    : Icons.error_outline_rounded,
                size: 36,
                color: isOffline
                    ? theme.colorScheme.onSurfaceVariant
                    : AppColors.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isOffline ? "You're offline" : l10n.communityLoadError,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOffline
                  ? 'Community features require an internet connection.'
                  : 'Unable to load. Please try again.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: context.appTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isOffline) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.communityRetry),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  side: BorderSide(color: theme.colorScheme.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
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
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final lang = filters[i].key;
          final label = filters[i].value;
          final isActive = activeLanguage == lang;
          return GestureDetector(
            onTap: () => onChanged(lang),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? context.appInteractive
                    : context.appSurfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : context.appTextSecondary,
                ),
              ),
            ),
          );
        },
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
        return Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary),
          ),
        );
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
          color: Theme.of(context).colorScheme.primary,
          onRefresh: () async => context
              .read<DiscoverBloc>()
              .add(DiscoverLoadRequested(language: state.language)),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: state.fellowships.length + (state.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == state.fellowships.length) {
                // Bottom loading indicator — shown while fetching next page.
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary),
                    ),
                  ),
                );
              }
              final f = state.fellowships[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PublicFellowshipCard(
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_off_outlined,
                size: 64, color: context.appTextTertiary),
            const SizedBox(height: 16),
            Text(
              l10n.discoverEmpty,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.appTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasLanguageFilter) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onShowAll,
                child: Text(
                  l10n.discoverEmptyShowAll,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
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

class _PublicFellowshipCard extends StatelessWidget {
  final PublicFellowshipEntity fellowship;
  final bool isJoining;
  final VoidCallback onJoin;

  const _PublicFellowshipCard({
    required this.fellowship,
    required this.isJoining,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isFull = fellowship.memberCount >= fellowship.maxMembers;
    final initials = _initials(fellowship.name);
    final avatarColor = _avatarColor(fellowship.name);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar ────────────────────────────────────────────────────────
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: avatarColor,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ── Content ───────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fellowship.name,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                // Language badge + member count
                Row(
                  children: [
                    _LanguageBadge(language: fellowship.language),
                    const SizedBox(width: 8),
                    Icon(Icons.people_outline_rounded,
                        size: 12, color: context.appTextTertiary),
                    const SizedBox(width: 3),
                    Text(
                      l10n.discoverMembersCount(
                          fellowship.memberCount, fellowship.maxMembers),
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: context.appTextTertiary),
                    ),
                  ],
                ),
                if (fellowship.mentorName != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 12, color: context.appTextTertiary),
                      const SizedBox(width: 3),
                      Text(
                        fellowship.mentorName!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: context.appTextTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
                if (fellowship.currentStudyTitle != null) ...[
                  const SizedBox(height: 6),
                  _StudyChip(
                      title: fellowship.currentStudyTitle, guideIndex: 0),
                ],
                if (fellowship.description != null &&
                    fellowship.description!.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    fellowship.description!,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        height: 1.4,
                        color: context.appTextSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),

          // ── Join / Full button ─────────────────────────────────────────────
          _JoinButton(isFull: isFull, isJoining: isJoining, onJoin: onJoin),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF6A4FB6),
      Color(0xFF3B82F6),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
      Color(0xFFEC4899),
    ];
    final hash = name.codeUnits.fold(0, (a, b) => a + b);
    return colors[hash % colors.length];
  }
}

// ---------------------------------------------------------------------------
// Language badge
// ---------------------------------------------------------------------------

class _LanguageBadge extends StatelessWidget {
  final String language;

  const _LanguageBadge({required this.language});

  @override
  Widget build(BuildContext context) {
    final labels = {'en': 'EN', 'hi': 'HI', 'ml': 'ML'};
    final badgeColors = {
      'en': (bg: const Color(0xFF3B82F6), fg: Colors.white),
      'hi': (bg: const Color(0xFFF59E0B), fg: Colors.white),
      'ml': (bg: const Color(0xFF10B981), fg: Colors.white),
    };
    final colors = badgeColors[language] ??
        (bg: context.appSurfaceVariant, fg: context.appTextSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.bg.withValues(alpha: 0.35)),
      ),
      child: Text(
        labels[language] ?? language.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: colors.bg,
          letterSpacing: 0.5,
        ),
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

    if (isFull) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: context.appSurfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.appBorder),
        ),
        child: Text(
          l10n.discoverFull,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: context.appTextTertiary,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: isJoining ? null : onJoin,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: isJoining ? null : AppTheme.primaryGradient,
          color: isJoining ? context.appSurfaceVariant : null,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isJoining
              ? null
              : [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: isJoining
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary),
                ),
              )
            : Text(
                l10n.discoverJoinButton,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Enums + helpers
// ---------------------------------------------------------------------------

enum _CommunityAction { join, create }

bool _canCreateFellowship(BuildContext context, FellowshipListState listState) {
  final authState = context.read<AuthBloc>().state;
  if (authState is auth_states.AuthenticatedState && authState.isAdmin) {
    return true;
  }
  if (listState.fellowships.any((f) => f.userRole == 'mentor')) return true;
  try {
    final subState = context.read<SubscriptionBloc>().state;
    if (subState is UserSubscriptionStatusLoaded) {
      final plan = subState.currentPlan;
      if (plan == 'plus' || plan == 'premium') {
        return true;
      }
    }
  } catch (_) {}
  return false;
}
