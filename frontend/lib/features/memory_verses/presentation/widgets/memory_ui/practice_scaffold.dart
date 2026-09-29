import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/style.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/top_bar.dart';

/// Page frame shared by every practice mode:
///
/// * [MemoryPracticeTopBar] — close (x), title/subtitle, timer pill;
/// * [body] — scrollable (by default) with 16px gutters;
/// * [bottomBar] — normally an `MemoryActionBar`, pinned above the safe area.
///
/// The scaffold owns no state: pass the live [elapsedSeconds] from the
/// page's existing timer and keep all logic in the page.
class MemoryPracticeScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// Timer pill value; `null` hides it.
  final int? elapsedSeconds;

  /// Close handler; defaults to `Navigator.maybePop`. Pages that confirm
  /// before leaving should pass their existing handler here.
  final VoidCallback? onClose;

  /// Extra top bar actions placed before the timer pill.
  final List<Widget> actions;

  final Widget body;
  final Widget? bottomBar;

  /// Wrap [body] in a `SingleChildScrollView`. Set false when the body
  /// manages its own scrolling or must fill the height (e.g. `Expanded`).
  final bool scrollable;

  /// Padding around [body].
  final EdgeInsetsGeometry padding;

  /// Forwarded to [Scaffold.resizeToAvoidBottomInset] (keep true for
  /// typing modes so the field stays above the keyboard).
  final bool resizeToAvoidBottomInset;

  /// Optional key for the underlying [Scaffold] (snackbars, showcase).
  final Key? scaffoldKey;

  const MemoryPracticeScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.elapsedSeconds,
    this.onClose,
    this.actions = const [],
    this.bottomBar,
    this.scrollable = true,
    this.padding =
        const EdgeInsets.fromLTRB(kMemoryGutter, 8, kMemoryGutter, 24),
    this.resizeToAvoidBottomInset = true,
    this.scaffoldKey,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final content = Padding(padding: padding, child: body);
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: palette.page,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: MemoryPracticeTopBar(
        title: title,
        subtitle: subtitle,
        elapsedSeconds: elapsedSeconds,
        onClose: onClose,
        actions: actions,
      ),
      body: scrollable
          ? SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              child: content,
            )
          : content,
      bottomNavigationBar: bottomBar,
    );
  }
}
