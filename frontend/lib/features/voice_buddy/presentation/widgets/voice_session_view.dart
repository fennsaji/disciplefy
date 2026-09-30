import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/domain/entities/voice_conversation_entity.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_conversation_state.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/conversation_bubble.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/discipler_session_widgets.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/voice_button.dart';
import 'package:disciplefy_bible_study/shared/widgets/clickable_scripture_text.dart';
import 'package:disciplefy_bible_study/shared/widgets/welcome_chrome.dart';

/// State of the mic control for [state]. A spoken reply wins over listening
/// (continuous mode may already be listening while TTS plays), then listening,
/// then a reply being prepared.
VoiceButtonState voiceButtonStateFor(VoiceConversationState state) {
  if (state.isPlaying) return VoiceButtonState.speaking;
  if (state.isListening) return VoiceButtonState.listening;
  if (state.status == VoiceConversationStatus.processing ||
      state.status == VoiceConversationStatus.streaming) {
    return VoiceButtonState.processing;
  }
  return VoiceButtonState.idle;
}

/// Status of the typed chat. Unlike [voiceButtonStateFor], a stale
/// `isListening` never reads as "Listening": only a mic that is actually
/// recording does. A reply being prepared wins over listening, and a spoken
/// reply wins over both.
VoiceButtonState chatStatusFor(VoiceConversationState state) {
  if (state.isPlaying) return VoiceButtonState.speaking;
  if (state.status == VoiceConversationStatus.processing ||
      state.status == VoiceConversationStatus.streaming) {
    return VoiceButtonState.processing;
  }
  if (state.isListening && state.status == VoiceConversationStatus.listening) {
    return VoiceButtonState.listening;
  }
  return VoiceButtonState.idle;
}

/// Short status for headers: Ready / Listening / Thinking / Speaking.
String sessionStatusLabel(BuildContext context, VoiceButtonState state) {
  switch (state) {
    case VoiceButtonState.speaking:
      return context.tr(TranslationKeys.voiceSessionStatusSpeaking);
    case VoiceButtonState.listening:
      return context.tr(TranslationKeys.voiceSessionStatusListening);
    case VoiceButtonState.processing:
      return context.tr(TranslationKeys.voiceSessionStatusThinking);
    case VoiceButtonState.idle:
      return context.tr(TranslationKeys.voiceSessionStatusReady);
  }
}

/// The hands-free view of a conversation: the listening orb and live
/// transcription, the spoken reply with the question it answers, and the
/// keyboard / mic / end controls.
class VoiceSessionView extends StatelessWidget {
  final VoiceConversationState state;

  /// Name of the language Discipler speaks.
  final String languageName;

  /// Hint under the orb for the current mic state.
  final String hint;

  /// Allowance chip; null hides it.
  final QuotaDisplay? quota;

  /// Close arrow, shown only when the page is pushed (not as a tab).
  final VoidCallback? onBack;
  final VoidCallback onSettings;
  final VoidCallback onKeyboard;
  final VoidCallback onEnd;
  final VoidCallback onInterrupt;

  final VoidCallback onVoiceTap;
  final VoidCallback onVoiceTapDown;
  final VoidCallback onVoiceTapUp;
  final VoidCallback onVoiceTapCancel;
  final ValueChanged<String> onScriptureReferenceTap;

  const VoiceSessionView({
    super.key,
    required this.state,
    required this.languageName,
    required this.hint,
    required this.quota,
    required this.onSettings,
    required this.onKeyboard,
    required this.onEnd,
    required this.onInterrupt,
    required this.onVoiceTap,
    required this.onVoiceTapDown,
    required this.onVoiceTapUp,
    required this.onVoiceTapCancel,
    required this.onScriptureReferenceTap,
    this.onBack,
  });

  ConversationMessageEntity? _last(MessageRole role) {
    for (final message in state.messages.reversed) {
      if (message.role == role) return message;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final buttonState = voiceButtonStateFor(state);
    final media = MediaQuery.of(context);

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: media.size.height * 0.62,
          child: const WelcomePhotoBackdrop(
              asset: disciplerHeaderPhoto, blurred: true),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(context, palette),
              if (quota != null && quota!.isVisible)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: DisciplerQuotaChip(display: quota!, onPhoto: true),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: _buildBody(context, palette, buttonState),
                ),
              ),
              _buildControls(context, palette, buttonState),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context, ReaderPalette palette) {
    final subtitle = [
      if (state.isContinuousMode)
        context.tr('voice_buddy.voice_controls.continuous_mode'),
      languageName,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.close),
              color: palette.text,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            )
          else
            const SizedBox(width: 8),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('voice_buddy.title'),
                  style: AppFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                    height: 1.25,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: palette.muted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined),
            color: palette.text,
            tooltip: context.tr('voice_buddy.settings.title'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ReaderPalette palette,
    VoiceButtonState buttonState,
  ) {
    final lastUser = _last(MessageRole.user);
    final lastReply = _last(MessageRole.assistant);
    final streaming = state.streamingResponse;

    switch (buttonState) {
      case VoiceButtonState.speaking:
        return _ReplyView(
          reply: streaming.isNotEmpty ? streaming : lastReply?.contentText,
          references:
              streaming.isNotEmpty ? null : lastReply?.scriptureReferences,
          question: lastUser?.contentText,
          status: sessionStatusLabel(context, buttonState),
          speaking: true,
          onScriptureReferenceTap: onScriptureReferenceTap,
        );
      case VoiceButtonState.listening:
        final transcription = state.currentTranscription ?? '';
        return _OrbView(
          orb: _orb(
            buttonState,
            WaveformBars(color: Colors.white, height: 56, count: 9),
          ),
          hint: hint,
          emphasiseHint: true,
          card: state.showTranscription && transcription.isNotEmpty
              ? _YouCard(text: transcription)
              : null,
        );
      case VoiceButtonState.processing:
        if (streaming.isNotEmpty) {
          return _ReplyView(
            reply: streaming,
            question: lastUser?.contentText,
            status: sessionStatusLabel(context, buttonState),
            speaking: false,
            onScriptureReferenceTap: onScriptureReferenceTap,
          );
        }
        return _OrbView(
          orb: _orb(
            buttonState,
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
          hint: hint,
          card: lastUser != null ? _YouCard(text: lastUser.contentText) : null,
        );
      case VoiceButtonState.idle:
        if (lastReply != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReplyView(
                reply: lastReply.contentText,
                references: lastReply.scriptureReferences,
                question: lastUser?.contentText,
                status: sessionStatusLabel(context, buttonState),
                speaking: false,
                onScriptureReferenceTap: onScriptureReferenceTap,
              ),
              const SizedBox(height: 20),
              _HintText(hint),
            ],
          );
        }
        return _OrbView(
          orb: _orb(
            buttonState,
            const Icon(Icons.mic_none_rounded, size: 56, color: Colors.white),
          ),
          hint: hint,
          footnote: state.messages.isEmpty
              ? context.tr('voice_buddy.conversation.empty_hint')
              : null,
          card: lastUser != null ? _YouCard(text: lastUser.contentText) : null,
        );
    }
  }

  /// The big orb, answering taps exactly like the mic button below it.
  Widget _orb(VoiceButtonState buttonState, Widget content) {
    return VoiceMicGestures(
      key: const ValueKey('voice-session-orb'),
      state: buttonState,
      isContinuousMode: state.isContinuousMode,
      semanticLabel: hint,
      onTap: onVoiceTap,
      onTapDown: onVoiceTapDown,
      onTapUp: onVoiceTapUp,
      onTapCancel: onVoiceTapCancel,
      child: VoiceOrb(child: content),
    );
  }

  Widget _buildControls(
    BuildContext context,
    ReaderPalette palette,
    VoiceButtonState buttonState,
  ) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final Widget centre;
    if (buttonState == VoiceButtonState.speaking) {
      centre = Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FilledButton(
            onPressed: onInterrupt,
            style: FilledButton.styleFrom(
              backgroundColor: palette.ctaFill,
              foregroundColor: palette.ctaInk,
              minimumSize: const Size(0, 56),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pan_tool_outlined, size: 20, color: palette.ctaInk),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    context.tr('voice_buddy.voice_controls.tap_to_interrupt'),
                    textAlign: TextAlign.center,
                    style: AppFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.ctaInk,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      centre = VoiceButton(
        state: buttonState,
        isContinuousMode: state.isContinuousMode,
        semanticLabel: hint,
        onTap: onVoiceTap,
        onTapDown: onVoiceTapDown,
        onTapUp: onVoiceTapUp,
        onTapCancel: onVoiceTapCancel,
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SessionRoundButton(
            icon: Icons.keyboard_outlined,
            tooltip: context.tr(TranslationKeys.voiceSessionTypingMode),
            onPressed: onKeyboard,
            fill: palette.raised,
            ink: palette.text,
            size: 56,
          ),
          centre,
          SessionRoundButton(
            icon: Icons.close_rounded,
            tooltip: context.tr('voice_buddy.voice_controls.end_tooltip'),
            onPressed: onEnd,
            fill: endTint(palette),
            ink: endInk(palette),
            size: 56,
          ),
        ],
      ),
    );
  }
}

class _HintText extends StatelessWidget {
  final String text;
  final bool emphasise;

  const _HintText(this.text, {this.emphasise = false});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: emphasise
          ? AppFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: palette.accentIcon,
              height: 1.4,
            )
          : AppFonts.inter(fontSize: 14, color: palette.muted, height: 1.4),
    );
  }
}

/// Orb (already tappable), hint, and an optional "YOU" card.
class _OrbView extends StatelessWidget {
  final Widget orb;
  final String hint;
  final bool emphasiseHint;
  final String? footnote;
  final Widget? card;

  const _OrbView({
    required this.orb,
    required this.hint,
    this.emphasiseHint = false,
    this.footnote,
    this.card,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(child: orb),
        const SizedBox(height: 32),
        _HintText(hint, emphasise: emphasiseHint),
        if (footnote != null) ...[
          const SizedBox(height: 8),
          Text(
            footnote!,
            textAlign: TextAlign.center,
            style: AppFonts.inter(
              fontSize: 14,
              color: palette.muted,
              height: 1.4,
            ),
          ),
        ],
        if (card != null) ...[const SizedBox(height: 24), card!],
      ],
    );
  }
}

/// Card with the user's words: live transcription, or the question sent.
class _YouCard extends StatelessWidget {
  final String text;

  const _YouCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SessionLabel(context.tr(TranslationKeys.voiceSessionYou)),
          const SizedBox(height: 8),
          Text(
            text,
            style: AppFonts.inter(
              fontSize: 18,
              color: palette.text,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// Discipler's reply in large type, its cited references, and the question.
class _ReplyView extends StatelessWidget {
  final String? reply;
  final List<String>? references;
  final String? question;
  final String status;
  final bool speaking;
  final ValueChanged<String> onScriptureReferenceTap;

  const _ReplyView({
    required this.reply,
    required this.question,
    required this.status,
    required this.speaking,
    required this.onScriptureReferenceTap,
    this.references,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final refs = references ?? const <String>[];
    final statusColor = speaking ? palette.gold : palette.muted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const DisciplerAvatar(radius: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('voice_buddy.title'),
                    style: AppFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (speaking) ...[
                        WaveformBars(
                          color: palette.gold,
                          height: 14,
                          barWidth: 3,
                          gap: 3,
                          count: 7,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          status,
                          style: AppFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (reply != null && reply!.isNotEmpty) ...[
          const SizedBox(height: 18),
          ClickableScriptureText(
            text: reply!,
            selectable: false,
            style: AppFonts.poppins(
              fontSize: 21,
              fontWeight: FontWeight.w500,
              color: palette.text,
              height: 1.45,
            ),
          ),
        ],
        if (refs.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final ref in refs)
                ScriptureReferenceChip(
                  reference: ref,
                  onTap: () => onScriptureReferenceTap(ref),
                ),
            ],
          ),
        ],
        if (question != null && question!.isNotEmpty) ...[
          const SizedBox(height: 20),
          Divider(height: 1, thickness: 1, color: palette.hairline),
          const SizedBox(height: 16),
          SessionLabel(context.tr(TranslationKeys.voiceSessionYouAsked)),
          const SizedBox(height: 6),
          Text(
            question!,
            style: AppFonts.inter(
              fontSize: 15,
              color: palette.muted,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}
