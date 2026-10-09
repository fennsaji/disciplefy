import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';

/// Label of a pill in the reader's bottom bar ("Listen", "Ask Discipler").
///
/// Both pills use this, so their labels are always the same size: never
/// scaled down to fit, a long label (Malayalam) wraps to a second line
/// instead.
class StudyBarLabel extends StatelessWidget {
  final String text;

  /// Null inherits the button's foreground colour.
  final Color? color;

  const StudyBarLabel(this.text, {super.key, this.color});

  static const double fontSize = 12.5;

  static TextStyle style(Color? color) => AppFonts.inter(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: color,
      );

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style: style(color),
    );
  }
}

/// A leading icon and a [StudyBarLabel], centred in a pill. When the label
/// would need more than two lines beside the icon (Malayalam at large text
/// sizes on a narrow phone), the icon is dropped so the words stay whole.
class StudyBarIconLabel extends StatelessWidget {
  final Widget icon;
  final double iconWidth;
  final double gap;
  final String text;
  final Color? color;

  const StudyBarIconLabel({
    super.key,
    required this.icon,
    required this.iconWidth,
    required this.text,
    this.gap = 8,
    this.color,
  });

  bool _fits(BuildContext context, double width) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: StudyBarLabel.style(color)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 2,
    )..layout(maxWidth: width);
    final fits = !painter.didExceedMaxLines;
    painter.dispose();
    return fits;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final showIcon = !constraints.hasBoundedWidth ||
          _fits(context, constraints.maxWidth - iconWidth - gap);
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showIcon) ...[icon, SizedBox(width: gap)],
          Flexible(child: StudyBarLabel(text, color: color)),
        ],
      );
    });
  }
}
