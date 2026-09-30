import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_form_parts.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_top_bars.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

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

/// Stateless inner widget holding the Scaffold, back bar, code entry and
/// button.
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
    final palette = ReaderPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: CommunityBackBar(
        title: l10n.joinFellowshipTitle,
        background: palette.page,
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: PopupIconCircle(
                  icon: Icons.group_add_rounded,
                  size: 76,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.joinFellowshipHeading,
                textAlign: TextAlign.center,
                style: AppFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.joinFellowshipInstructions,
                textAlign: TextAlign.center,
                style: AppFonts.inter(
                  fontSize: 14.5,
                  color: palette.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
              Center(
                child: _CodeTileInput(
                  controller: tokenController,
                  focusNode: tokenFocusNode,
                  enabled: !isLoading,
                  onSubmitted: onJoinPressed,
                ),
              ),
              const SizedBox(height: 32),
              CommunityWideCta(
                label: l10n.joinFellowshipButton,
                icon: Icons.group_add_rounded,
                loading: isLoading,
                onPressed: hasInput && !isLoading ? onJoinPressed : null,
              ),
              const SizedBox(height: 20),
              Text(
                l10n.joinFellowshipHelper,
                textAlign: TextAlign.center,
                style: AppFonts.inter(
                  fontSize: 12.5,
                  color: palette.dim,
                  height: 1.45,
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
                            ? const EdgeInsets.only(right: gap)
                            : null,
                        width: tileWidth,
                        height: tileHeight,
                        decoration: BoxDecoration(
                          color: hasChar ? palette.raised : palette.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isActive
                                ? palette.accentIcon
                                : (hasChar
                                    ? palette.outline
                                    : palette.hairline),
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: hasChar
                            ? Text(
                                text[i],
                                style: AppFonts.poppins(
                                  fontSize: tileWidth * 0.5,
                                  fontWeight: FontWeight.w600,
                                  color: palette.text,
                                  height: 1,
                                ),
                              )
                            : (i == 0 && text.isEmpty && !isFocused
                                ? Text(
                                    '·',
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: palette.dim,
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
