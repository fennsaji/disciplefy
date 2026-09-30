import 'package:flutter/material.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/reader_palette.dart';
import '../../../../shared/widgets/popup.dart';
import '../../../settings/presentation/widgets/settings_group.dart';

/// Sheet offered after the reader takes a screenshot of a study guide.
///
/// Show it with a transparent sheet background.
class ScreenshotShareSheet extends StatelessWidget {
  final VoidCallback onShareText;

  /// Shown only when the reader belongs to at least one fellowship.
  final VoidCallback? onShareFellowship;

  const ScreenshotShareSheet({
    super.key,
    required this.onShareText,
    this.onShareFellowship,
  });

  @override
  Widget build(BuildContext context) {
    return PopupSheet(
      children: [
        PopupHeader(
          icon: const PopupIconCircle(icon: Icons.screenshot_monitor_rounded),
          eyebrow: context.tr(TranslationKeys.studyUiScreenshotEyebrow),
          title: context.tr(TranslationKeys.studyUiScreenshotTitle),
          body: context.tr(TranslationKeys.studyUiScreenshotBody),
        ),
        const SizedBox(height: 24),
        PopupPrimaryButton(
          label: context.tr(TranslationKeys.commonShare),
          icon: Icons.share_rounded,
          onPressed: onShareText,
        ),
        if (onShareFellowship != null) ...[
          const SizedBox(height: 10),
          SettingsButton(
            label: context.tr(TranslationKeys.studyUiScreenshotShareFellowship),
            icon: Icons.group_rounded,
            kind: SettingsButtonKind.neutral,
            onPressed: onShareFellowship,
          ),
        ],
        const SizedBox(height: 6),
        PopupTextButton(
          label: context.tr(TranslationKeys.studyUiDismiss),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Banner above a guide whose generation stopped part-way.
class GenerationInterruptedBanner extends StatelessWidget {
  /// Retries generation; the retry pill is hidden when null.
  final VoidCallback? onRetry;

  const GenerationInterruptedBanner({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.hairline),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.end,
        spacing: 12,
        runSpacing: 10,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: context.appWarning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr(TranslationKeys.studyUiGenerationInterrupted),
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: palette.text,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded,
                  size: 18, color: palette.accentIcon),
              label: Text(
                context.tr(TranslationKeys.commonRetry),
                style: AppFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: palette.accentIcon,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: palette.raised,
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
        ],
      ),
    );
  }
}
