import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/fellowship_list/fellowship_list_bloc.dart';
import '../bloc/fellowship_list/fellowship_list_event.dart';
import '../bloc/fellowship_list/fellowship_list_state.dart';

/// Screen that allows a user to join a fellowship by entering an invite code.
///
/// **Does NOT create its own [BlocProvider].** The [FellowshipListBloc] is
/// provided by the parent [CommunityTabScreen] (via the GoRouter sub-route
/// relationship) and is accessed here via [context.read].
///
/// Uses [BlocConsumer] to:
/// - Listen: pop on join success, show error SnackBar on join failure.
/// - Build: overlay a loading spinner while the join request is in-flight.
class JoinFellowshipScreen extends StatefulWidget {
  const JoinFellowshipScreen({super.key});

  @override
  State<JoinFellowshipScreen> createState() => _JoinFellowshipScreenState();
}

class _JoinFellowshipScreenState extends State<JoinFellowshipScreen> {
  final TextEditingController _tokenController = TextEditingController();
  final FocusNode _tokenFocusNode = FocusNode();

  // Tracks whether the text field is non-empty to drive button enabled state.
  bool _hasInput = false;

  @override
  void initState() {
    super.initState();
    _tokenController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final nonEmpty = _tokenController.text.trim().isNotEmpty;
    if (nonEmpty != _hasInput) {
      setState(() => _hasInput = nonEmpty);
    }
  }

  @override
  void dispose() {
    _tokenController.removeListener(_onTextChanged);
    _tokenController.dispose();
    _tokenFocusNode.dispose();
    super.dispose();
  }

  void _onJoinPressed(BuildContext context) {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;
    context.read<FellowshipListBloc>().add(
          FellowshipJoinRequested(inviteToken: token),
        );
  }

  @override
  Widget build(BuildContext context) {
    // JoinFellowshipScreen owns its own BLoC because GoRouter pushes it as a
    // separate navigator page — parent route widget-tree providers are not
    // accessible from child route pages. After a successful join we pop(true)
    // so the caller can reload the fellowship list.
    return BlocProvider<FellowshipListBloc>(
      create: (_) => sl<FellowshipListBloc>(),
      child: _JoinFellowshipConsumer(
        tokenController: _tokenController,
        tokenFocusNode: _tokenFocusNode,
        hasInput: _hasInput,
        onJoinPressed: _onJoinPressed,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inner BlocConsumer — reads from the BlocProvider created above.
// ---------------------------------------------------------------------------

class _JoinFellowshipConsumer extends StatelessWidget {
  final TextEditingController tokenController;
  final FocusNode tokenFocusNode;
  final bool hasInput;
  final void Function(BuildContext) onJoinPressed;

  const _JoinFellowshipConsumer({
    required this.tokenController,
    required this.tokenFocusNode,
    required this.hasInput,
    required this.onJoinPressed,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FellowshipListBloc, FellowshipListState>(
      // Only react when joinStatus actually changes — avoids spurious rebuilds.
      listenWhen: (previous, current) =>
          previous.joinStatus != current.joinStatus,
      listener: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        if (state.joinStatus == FellowshipJoinStatus.success) {
          // Pop with true so the community tab knows to reload its list.
          context.pop(true);
        } else if (state.joinStatus == FellowshipJoinStatus.failure) {
          final message = state.joinError ?? l10n.communityJoinFailed;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
        }
      },
      buildWhen: (previous, current) =>
          previous.joinStatus != current.joinStatus,
      builder: (context, state) {
        final isLoading = state.joinStatus == FellowshipJoinStatus.loading;

        return Stack(
          children: [
            _JoinFellowshipBody(
              tokenController: tokenController,
              tokenFocusNode: tokenFocusNode,
              isLoading: isLoading,
              hasInput: hasInput,
              onJoinPressed: () => onJoinPressed(context),
            ),
            // Loading overlay — blocks interaction while the join request
            // is in-flight without navigating away from the screen.
            if (isLoading) const _LoadingOverlay(),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _JoinFellowshipBody
// ---------------------------------------------------------------------------

/// Stateless inner widget holding the Scaffold, AppBar, form field and button.
class _JoinFellowshipBody extends StatelessWidget {
  final TextEditingController tokenController;
  final FocusNode tokenFocusNode;
  final bool isLoading;
  final bool hasInput;
  final VoidCallback onJoinPressed;

  const _JoinFellowshipBody({
    required this.tokenController,
    required this.tokenFocusNode,
    required this.isLoading,
    required this.hasInput,
    required this.onJoinPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.appScaffold,
      appBar: AppBar(
        backgroundColor: context.appScaffold,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.appTextPrimary,
            size: 20,
          ),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: Text(
          l10n.joinFellowshipTitle,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Icon ──────────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.group_add_rounded,
                    size: 44,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Heading ───────────────────────────────────────────────────
              Center(
                child: Text(
                  l10n.joinFellowshipHeading,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 10),

              Center(
                child: Text(
                  l10n.joinFellowshipInstructions,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: context.appTextSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 40),

              // ── Invite code field ─────────────────────────────────────────
              Text(
                l10n.joinFellowshipCodeLabel,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                  letterSpacing: 0.3,
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: tokenController,
                focusNode: tokenFocusNode,
                enabled: !isLoading,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: context.appTextPrimary,
                  letterSpacing: 1.2,
                ),
                decoration: InputDecoration(
                  hintText: l10n.joinFellowshipCodeHint,
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    color: context.appTextTertiary,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w400,
                  ),
                  filled: true,
                  fillColor: context.appInputFill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.appBorder,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.appBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.appBorder,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.vpn_key_outlined,
                    size: 20,
                    color: context.appTextTertiary,
                  ),
                ),
                onSubmitted: (_) {
                  if (!isLoading && tokenController.text.trim().isNotEmpty) {
                    onJoinPressed();
                  }
                },
              ),

              const SizedBox(height: 36),

              // ── Join button ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: _JoinButton(
                  isLoading: isLoading,
                  isEnabled: hasInput && !isLoading,
                  onPressed: onJoinPressed,
                  label: l10n.joinFellowshipButton,
                ),
              ),

              const SizedBox(height: 20),

              // ── Helper note ───────────────────────────────────────────────
              Center(
                child: Text(
                  l10n.joinFellowshipHelper,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: context.appTextTertiary.withOpacity(0.8),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _JoinButton
// ---------------------------------------------------------------------------

/// Gradient primary button for the join action.
///
/// Renders a gradient when enabled, a flat muted surface when disabled.
class _JoinButton extends StatelessWidget {
  final bool isLoading;
  final bool isEnabled;
  final VoidCallback onPressed;
  final String label;

  const _JoinButton({
    required this.isLoading,
    required this.isEnabled,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (!isEnabled) {
      // Disabled appearance — no gradient, muted color.
      return Container(
        decoration: BoxDecoration(
          color: context.appBorder,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.appTextTertiary,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.group_add_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LoadingOverlay
// ---------------------------------------------------------------------------

/// Semi-transparent overlay with a centered spinner shown during the
/// join request. Blocks touch input without navigating away.
class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.overlayLight,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary),
          ),
        ),
      ),
    );
  }
}
