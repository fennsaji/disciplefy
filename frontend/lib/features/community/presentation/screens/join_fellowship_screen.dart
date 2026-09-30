import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_form_parts.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_top_bars.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';
import 'package:disciplefy_bible_study/shared/widgets/photo_wash.dart';

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

  // Why the last join attempt failed, shown under the code cells until the
  // code is edited.
  String? _joinError;

  // Code the last join attempt used, so the error clears only on a real edit.
  String _submittedToken = '';

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
    final clearError = _joinError != null &&
        _tokenController.text.trim().toUpperCase() != _submittedToken;
    if (nonEmpty != _hasInput || clearError) {
      setState(() {
        _hasInput = nonEmpty;
        if (clearError) _joinError = null;
      });
    }
  }

  void _onJoinFailed(String message) {
    setState(() => _joinError = message);
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
    _submittedToken = token;
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
            errorText: _joinError,
            onJoinPressed: _onJoinPressed,
            onJoinFailed: _onJoinFailed,
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
  final String? errorText;
  final void Function(BuildContext) onJoinPressed;
  final ValueChanged<String> onJoinFailed;

  const _JoinFellowshipConsumer({
    required this.tokenController,
    required this.tokenFocusNode,
    required this.hasInput,
    required this.errorText,
    required this.onJoinPressed,
    required this.onJoinFailed,
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
          // Open the group — also when the user was already a member. The
          // community tab reloads its list when they come back from it.
          final fellowshipId = state.joinedFellowshipId;
          if (fellowshipId == null) {
            context.canPop() ? context.pop(true) : context.go('/community');
          } else if (context.canPop()) {
            context.pushReplacement('/community/$fellowshipId');
          } else {
            context.go('/community/$fellowshipId');
          }
        } else if (state.joinStatus == FellowshipJoinStatus.failure) {
          final message = state.joinError ?? l10n.communityJoinFailed;
          onJoinFailed(message);
          showAppSnackBar(context, message, tone: AppSnackTone.error);
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
              errorText: errorText,
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

/// Page layout: photo wash, back arrow, gold eyebrow, title and subtitle,
/// the code cells with any error under them, the join pill and a helper line.
class _JoinFellowshipBody extends StatelessWidget {
  final TextEditingController tokenController;
  final FocusNode tokenFocusNode;
  final bool isLoading;
  final bool hasInput;
  final String? errorText;
  final VoidCallback onJoinPressed;

  const _JoinFellowshipBody({
    required this.tokenController,
    required this.tokenFocusNode,
    required this.isLoading,
    required this.hasInput,
    required this.errorText,
    required this.onJoinPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    final error = errorText;
    // Clears the system inset and, when shown inside the tab shell, the
    // floating dock (the shell adds its height to this padding).
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: palette.page,
      body: PhotoWash(
        image: PhotoWash.communityTabImage,
        height: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CommunityBackBar(onBack: () => context.pop()),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 8, 24, bottom + 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CommunitySectionLabel(l10n.joinFellowshipTitle),
                    const SizedBox(height: 10),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.joinFellowshipHeading,
                        style: AppFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.joinFellowshipInstructions,
                      style: AppFonts.inter(
                        fontSize: 15,
                        color: palette.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _CodeTileInput(
                      controller: tokenController,
                      focusNode: tokenFocusNode,
                      enabled: !isLoading,
                      hasError: error != null,
                      onSubmitted: onJoinPressed,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          key: const Key('join_fellowship_error'),
                          textAlign: TextAlign.center,
                          style: AppFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color:
                                SettingsToneColors.of(context, SettingsTone.red)
                                    .foreground,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    CommunityWideCta(
                      label: l10n.joinFellowshipButton,
                      icon: Icons.group_add_rounded,
                      loading: isLoading,
                      onPressed: hasInput && !isLoading ? onJoinPressed : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.joinFellowshipHelper,
                      textAlign: TextAlign.center,
                      style: AppFonts.inter(
                        fontSize: 13.5,
                        color: palette.muted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    final palette = ReaderPalette.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: palette.page.withValues(alpha: 0.55),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(palette.accentIcon),
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
  final bool hasError;
  final VoidCallback? onSubmitted;

  const _CodeTileInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    this.hasError = false,
    this.onSubmitted,
  });

  static const int _length = 6;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        // Fit all tiles within available width; clamp between 40–52px per tile.
        final tileWidth =
            ((constraints.maxWidth - gap * (_length - 1)) / _length)
                .clamp(40.0, 52.0);
        final tileHeight = tileWidth * 1.2;
        final rowWidth = tileWidth * _length + gap * (_length - 1);

        final errorInk =
            SettingsToneColors.of(context, SettingsTone.red).foreground;
        // Rebuilds on typing and on focus changes, so the gold focus ring
        // follows the keyboard.
        return ListenableBuilder(
          listenable: Listenable.merge([controller, focusNode]),
          builder: (context, _) {
            final text = controller.text.toUpperCase();
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
                      // The next empty cell, or the last one once the code is full.
                      final isActive = enabled &&
                          isFocused &&
                          i ==
                              (text.length < _length
                                  ? text.length
                                  : _length - 1);

                      return Container(
                        margin: i < _length - 1
                            ? const EdgeInsets.only(right: gap)
                            : null,
                        width: tileWidth,
                        height: tileHeight,
                        decoration: BoxDecoration(
                          color: palette.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isActive
                                ? palette.gold
                                : (hasError ? errorInk : palette.hairline),
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: hasChar
                            ? Text(
                                text[i],
                                style: AppFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: palette.text,
                                  height: 1,
                                ),
                              )
                            : null,
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
