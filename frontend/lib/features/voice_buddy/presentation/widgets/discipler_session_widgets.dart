import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/domain/entities/voice_preferences_entity.dart';

/// Small building blocks shared by the Discipler start screen, chat and
/// voice session.

/// Photo behind the Discipler headers.
const String disciplerHeaderPhoto = 'assets/images/hero/night_stars.webp';

/// Red used for "End" controls: a tint fill with red ink.
Color endTint(ReaderPalette palette) =>
    AppColors.error.withValues(alpha: palette.isDark ? 0.18 : 0.12);
Color endInk(ReaderPalette palette) =>
    palette.isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);

/// Darkest and lightest pixels [disciplerHeaderPhoto] can show once decoded
/// as a wash, used to check what sits over the header against the worst case.
const Color disciplerPhotoDarkestPixel = Color(0xFF071521);
const Color disciplerPhotoLightestPixel = Color(0xFF917BBE);

/// Deep red label for an exhausted allowance: Red-800 on light, Red-300 on
/// dark, both 5.5:1 or more on [quotaWarningFill].
Color quotaWarningInk(ReaderPalette palette) =>
    palette.isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);

/// Opaque red tint, so the photo never shows through the pill.
Color quotaWarningFill(ReaderPalette palette) =>
    Color.alphaBlend(endTint(palette), palette.raised);

/// Whether the monthly allowance is shown, and how.
///
/// Unlimited plans show nothing. A plan without Discipler (a limit of 0)
/// shows a calm "Not in your plan · See plans" link. A plan with N a month
/// shows "{left} of {N} left this month" while quota alerts are on or when
/// one or none is left; it turns red only when none is left.
class QuotaDisplay {
  final VoiceQuotaEntity quota;
  final bool notifyQuota;

  /// Opens the plans when the "not in your plan" link is tapped.
  final VoidCallback? onSeePlans;

  const QuotaDisplay(this.quota, {required this.notifyQuota, this.onSeePlans});

  /// The server reports unlimited as -1 or 999999.
  static const int _unlimitedFloor = 999999;

  bool get isUnlimited =>
      quota.tier == 'premium' ||
      quota.quotaLimit < 0 ||
      quota.quotaRemaining < 0 ||
      quota.quotaLimit >= _unlimitedFloor;
  bool get isNotInPlan => !isUnlimited && quota.quotaLimit == 0;
  bool get isExhausted =>
      !isUnlimited && quota.quotaLimit > 0 && quota.quotaRemaining <= 0;
  bool get isLow =>
      !isUnlimited && quota.quotaLimit > 0 && quota.quotaRemaining <= 1;
  bool get isVisible => !isUnlimited && (isNotInPlan || notifyQuota || isLow);
}

/// Pill with the conversations left this month ("2 of 3 left this month"),
/// deep red when none is left, or a "Not in your plan · See plans" link.
/// Always on an opaque fill, so it reads the same over the header photo.
class DisciplerQuotaChip extends StatelessWidget {
  final QuotaDisplay display;

  const DisciplerQuotaChip({super.key, required this.display});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final quota = display.quota;
    final exhausted = display.isExhausted;
    final notInPlan = display.isNotInPlan;
    final ink = exhausted ? quotaWarningInk(palette) : palette.text;
    final iconInk = exhausted ? quotaWarningInk(palette) : palette.accentIcon;
    final fill = exhausted ? quotaWarningFill(palette) : palette.raised;
    final label = notInPlan
        ? context.tr(TranslationKeys.voiceSessionNotInPlan)
        : context.tr(TranslationKeys.voiceSessionQuotaLeft, {
            'remaining': quota.quotaRemaining,
            'limit': quota.quotaLimit,
          });

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            exhausted
                ? Icons.warning_amber_rounded
                : notInPlan
                    ? Icons.workspace_premium_outlined
                    : Icons.forum_outlined,
            size: 16,
            color: iconInk,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: AppFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ink,
                height: 1.3,
              ),
            ),
          ),
          if (notInPlan) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: palette.muted),
          ],
        ],
      ),
    );

    if (notInPlan) {
      return Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: display.onSeePlans,
            borderRadius: BorderRadius.circular(20),
            child: pill,
          ),
        ),
      );
    }
    return Semantics(
      label: '${context.tr('voice_buddy.conversations_remaining')}: $label',
      excludeSemantics: true,
      child: pill,
    );
  }
}

/// Round icon-only button (keyboard, mic, send, settings) with a tooltip.
class SessionRoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color fill;
  final Color ink;
  final double size;

  const SessionRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.fill,
    required this.ink,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: enabled ? fill : fill.withValues(alpha: 0.5),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                size: size * 0.46,
                color: enabled ? ink : ink.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Red-tinted "End" pill of the chat header.
class SessionEndPill extends StatelessWidget {
  final VoidCallback onPressed;

  const SessionEndPill({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Tooltip(
      message: context.tr('voice_buddy.voice_controls.end_tooltip'),
      child: Material(
        color: endTint(palette),
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            // Capped so a long translation wraps instead of squeezing the
            // name beside it.
            constraints: const BoxConstraints(
              minHeight: 40,
              minWidth: 56,
              maxWidth: 104,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Center(
                widthFactor: 1,
                child: Text(
                  context.tr('voice_buddy.conversation.end_button'),
                  textAlign: TextAlign.center,
                  style: AppFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: endInk(palette),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fixed heights of the listening waveform, as fractions of its height.
const List<double> _waveHeights = [
  0.5, 0.78, 0.42, 1.0, 0.6, 0.36, 0.7, 0.3, 0.86, 0.46, //
];

/// A still row of rounded bars — the listening waveform, or the small
/// "speaking" mark beside Discipler's name.
class WaveformBars extends StatelessWidget {
  final Color color;
  final double height;
  final double barWidth;
  final double gap;
  final int count;

  const WaveformBars({
    super.key,
    required this.color,
    this.height = 40,
    this.barWidth = 4,
    this.gap = 5,
    this.count = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Container(
                width: barWidth,
                height: height * _waveHeights[i % _waveHeights.length],
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(barWidth),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Big gold disc at the centre of the voice session.
class VoiceOrb extends StatelessWidget {
  final Widget child;
  final double size;

  const VoiceOrb({super.key, required this.child, this.size = 150});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.brandGold, AppColors.streakGlow],
        ),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Small tracked uppercase label ("YOU", "YOU ASKED", "TRY ASKING").
class SessionLabel extends StatelessWidget {
  final String text;
  final Color? color;

  const SessionLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Text(
      text.toUpperCase(),
      style: AppFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: color ?? palette.muted,
      ),
    );
  }
}
