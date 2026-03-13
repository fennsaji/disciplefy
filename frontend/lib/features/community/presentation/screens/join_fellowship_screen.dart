import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// Accepts an optional [initialToken] (from a deep link) which is pre-filled
/// into the code tiles and auto-submitted on the first frame.
///
/// Creates its own [FellowshipListBloc] so it can be pushed as a top-level
/// GoRouter route (deep link) without requiring a parent BlocProvider.
class JoinFellowshipScreen extends StatefulWidget {
  final String initialToken;
  const JoinFellowshipScreen({super.key, this.initialToken = ''});

  @override
  State<JoinFellowshipScreen> createState() => _JoinFellowshipScreenState();
}

class _JoinFellowshipScreenState extends State<JoinFellowshipScreen> {
  final TextEditingController _tokenController = TextEditingController();
  final FocusNode _tokenFocusNode = FocusNode();

  // Tracks whether the text field is non-empty to drive button enabled state.
  bool _hasInput = false;

  // True when a deep-link token was provided and hasn't been submitted yet.
  bool _shouldAutoSubmit = false;

  @override
  void initState() {
    super.initState();
    _tokenController.addListener(_onTextChanged);
    if (widget.initialToken.isNotEmpty) {
      _tokenController.text = widget.initialToken.toUpperCase();
      _shouldAutoSubmit = true;
    }
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
    final token = _tokenController.text.trim().toUpperCase();
    if (token.isEmpty) return;
    context.read<FellowshipListBloc>().add(
          FellowshipJoinRequested(inviteToken: token),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FellowshipListBloc>(
      create: (_) => sl<FellowshipListBloc>(),
      // Builder gives us a context that is inside the BlocProvider, allowing
      // the deep-link auto-submit callback to call context.read<FellowshipListBloc>().
      child: Builder(
        builder: (innerContext) {
          if (_shouldAutoSubmit) {
            _shouldAutoSubmit = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _onJoinPressed(innerContext);
            });
          }
          return _JoinFellowshipConsumer(
            tokenController: _tokenController,
            tokenFocusNode: _tokenFocusNode,
            hasInput: _hasInput,
            onJoinPressed: _onJoinPressed,
          );
        },
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
          // If opened via deep link there is nothing to pop — go directly.
          if (context.canPop()) {
            context.pop(true);
          } else {
            context.go('/community');
          }
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

              // ── Invite code tiles ─────────────────────────────────────────
              Center(
                child: _CodeTileInput(
                  controller: tokenController,
                  focusNode: tokenFocusNode,
                  enabled: !isLoading,
                  onSubmitted: onJoinPressed,
                ),
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

// ---------------------------------------------------------------------------
// _CodeTileInput — OTP-style 6-tile code entry
// ---------------------------------------------------------------------------

/// Displays 6 letter-tile boxes while capturing input via an invisible
/// underlying [TextField]. Supports paste, keyboard, and accessibility.
class _CodeTileInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback? onSubmitted;

  const _CodeTileInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    this.onSubmitted,
  });

  static const int _length = 6;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        // Fit all tiles within available width; clamp between 40–52px per tile.
        final tileWidth =
            ((constraints.maxWidth - gap * (_length - 1)) / _length)
                .clamp(40.0, 52.0);
        final tileHeight = tileWidth * 1.2;
        final rowWidth = tileWidth * _length + gap * (_length - 1);

        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final text = value.text.toUpperCase();
            final isFocused = focusNode.hasFocus;

            return Stack(
              alignment: Alignment.center,
              children: [
                // Invisible input catcher (paste + keyboard)
                SizedBox(
                  width: rowWidth,
                  height: tileHeight,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: enabled,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                      LengthLimitingTextInputFormatter(_length),
                    ],
                    style:
                        const TextStyle(color: Colors.transparent, fontSize: 1),
                    cursorColor: Colors.transparent,
                    cursorWidth: 0,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => onSubmitted?.call(),
                  ),
                ),
                // Visual tiles (pointer events pass through to TextField)
                IgnorePointer(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_length, (i) {
                      final hasChar = i < text.length;
                      final isActive = enabled && isFocused && i == text.length;

                      return Container(
                        margin: i < _length - 1
                            ? EdgeInsets.only(right: gap)
                            : null,
                        width: tileWidth,
                        height: tileHeight,
                        decoration: BoxDecoration(
                          color: hasChar
                              ? (isDark
                                  ? primary.withOpacity(0.15)
                                  : primary.withOpacity(0.08))
                              : (isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? primary
                                : (hasChar
                                    ? primary.withOpacity(0.4)
                                    : (isDark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade300)),
                            width: isActive ? 2 : 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: hasChar
                            ? Text(
                                text[i],
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: tileWidth * 0.52,
                                  fontWeight: FontWeight.w700,
                                  color: primary,
                                  height: 1,
                                ),
                              )
                            : (i == 0 && text.isEmpty && !isFocused
                                ? Text(
                                    '·',
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: isDark
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade400,
                                    ),
                                  )
                                : null),
                      );
                    }),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
