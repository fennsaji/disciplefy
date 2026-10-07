import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/shared/widgets/welcome_chrome.dart';

/// Form building blocks for the pre-auth screens (email, password reset,
/// phone, verification code, profile setup): a photo-header page, field
/// labels and decoration, an info card and a selectable chip.

/// Scrollable pre-auth form page: a scenery photo fading into the page, a
/// back button, gold eyebrow, Poppins title, optional subtitle and the form
/// [children] below.
class WelcomeFormPage extends StatelessWidget {
  final String photo;
  final Key? backKey;
  final String eyebrow;
  final String title;
  final Widget? subtitle;
  final List<Widget> children;

  const WelcomeFormPage({
    super.key,
    required this.photo,
    required this.eyebrow,
    required this.title,
    required this.children,
    this.subtitle,
    this.backKey,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final isNarrow = MediaQuery.sizeOf(context).width < 360;

    return Scaffold(
      backgroundColor: palette.page,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topInset + 230,
              child: WelcomePhotoBackdrop(
                asset: photo,
                alignment: Alignment.bottomCenter,
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      24, topInset + 8, 24, bottomInset + 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          key: backKey,
                          tooltip: MaterialLocalizations.of(context)
                              .backButtonTooltip,
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                          icon: Icon(
                            Icons.arrow_back,
                            color: palette.isDark ? Colors.white : palette.text,
                          ),
                          onPressed: () => context.pop(),
                        ),
                      ),
                      SizedBox(height: isNarrow ? 48 : 64),
                      WelcomeEyebrow(eyebrow),
                      const SizedBox(height: 10),
                      WelcomeTitle(title, fontSize: isNarrow ? 26 : 30),
                      if (subtitle != null) ...[
                        const SizedBox(height: 12),
                        subtitle!,
                      ],
                      const SizedBox(height: 32),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Style of the muted paragraph under a [WelcomeFormPage] title; lighter on
/// dark where it sits over the photo.
TextStyle welcomeSubtitleStyle(BuildContext context) {
  final palette = ReaderPalette.of(context);
  return AppFonts.inter(
    fontSize: 15.5,
    height: 1.45,
    color:
        palette.isDark ? Colors.white.withValues(alpha: 0.75) : palette.muted,
  );
}

/// Muted paragraph under a [WelcomeFormPage] title.
class WelcomeSubtitle extends StatelessWidget {
  final String text;

  const WelcomeSubtitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) =>
      Text(text, style: welcomeSubtitleStyle(context));
}

/// Label shown above a form field or a group of chips.
class WelcomeFieldLabel extends StatelessWidget {
  final String text;

  const WelcomeFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppFonts.inter(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: palette.muted,
        ),
      ),
    );
  }
}

/// Filled palette-card field with a hairline outline, an accent focus ring
/// and an optional leading icon.
InputDecoration welcomeFieldDecoration(
  BuildContext context, {
  IconData? icon,
  String? hint,
  Widget? suffix,
  EdgeInsetsGeometry contentPadding =
      const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
}) {
  final palette = ReaderPalette.of(context);
  final error = Theme.of(context).colorScheme.error;
  final radius = BorderRadius.circular(16);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    hintText: hint,
    // Long Hindi/Malayalam hints wrap instead of being cut.
    hintMaxLines: 2,
    hintStyle: AppFonts.inter(fontSize: 15.5, color: palette.dim),
    prefixIcon:
        icon == null ? null : Icon(icon, size: 21, color: palette.muted),
    suffixIcon: suffix,
    filled: true,
    fillColor: palette.card,
    counterText: '',
    contentPadding: contentPadding,
    border: border(palette.outline),
    enabledBorder: border(palette.outline),
    focusedBorder: border(palette.accentIcon, 1.5),
    errorBorder: border(error),
    focusedErrorBorder: border(error, 1.5),
    errorMaxLines: 3,
  );
}

/// Text style typed into a [welcomeFieldDecoration] field.
TextStyle welcomeFieldTextStyle(BuildContext context) =>
    AppFonts.inter(fontSize: 15.5, color: ReaderPalette.of(context).text);

/// Palette card with an accent icon, an optional bold [title] and a muted
/// [body], for notes under a form.
class WelcomeInfoCard extends StatelessWidget {
  final IconData icon;
  final String? title;
  final String body;

  const WelcomeInfoCard({
    super.key,
    required this.icon,
    required this.body,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: palette.accentIcon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  body,
                  style: AppFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stadium chip for single or multiple choice: raised with hairline when
/// off, the selected fill with white ink when on.
class WelcomeChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const WelcomeChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.selectedFill : palette.card,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? palette.selectedFill : palette.outline,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: selected ? Colors.white : palette.text,
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
