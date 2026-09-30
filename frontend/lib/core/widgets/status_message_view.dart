import 'package:flutter/material.dart';

import '../../shared/widgets/popup.dart';
import '../constants/app_fonts.dart';
import '../theme/reader_palette.dart';

/// Full-screen status message (error, maintenance) on the reader page colour:
/// a tinted icon circle, optional gold eyebrow, Poppins title, muted body,
/// an optional [detail] card and a column of pill [actions].
///
/// Scrolls on short screens and keeps its content clear of the system
/// navigation bar. An optional [topAction] (e.g. a home button) sits in the
/// top-start corner.
class StatusMessageView extends StatelessWidget {
  final IconData icon;
  final PopupTone tone;
  final String? eyebrow;
  final String title;
  final String? message;
  final Widget? detail;
  final List<Widget> actions;
  final Widget? topAction;

  const StatusMessageView({
    super.key,
    required this.icon,
    required this.title,
    this.tone = PopupTone.indigo,
    this.eyebrow,
    this.message,
    this.detail,
    this.actions = const [],
    this.topAction,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    final body = Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 56, 24, 24 + bottom),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupIconCircle(icon: icon, tone: tone, size: 64),
              const SizedBox(height: 20),
              if (eyebrow != null) ...[
                PopupEyebrow(eyebrow!),
                const SizedBox(height: 10),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                  height: 1.25,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: AppFonts.inter(
                    fontSize: 15,
                    color: palette.muted,
                    height: 1.5,
                  ),
                ),
              ],
              if (detail != null) ...[
                const SizedBox(height: 20),
                detail!,
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 28),
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  actions[i],
                ],
              ],
            ],
          ),
        ),
      ),
    );

    return ColoredBox(
      color: palette.page,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: body),
            if (topAction != null)
              PositionedDirectional(top: 4, start: 4, child: topAction!),
          ],
        ),
      ),
    );
  }
}

/// Card holding a server-supplied message inside a [StatusMessageView].
class StatusDetailCard extends StatelessWidget {
  final String text;

  const StatusDetailCard(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.hairline),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppFonts.inter(fontSize: 15, color: palette.text, height: 1.5),
      ),
    );
  }
}
