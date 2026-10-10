import 'package:flutter/widgets.dart';

/// Keeps [child] alive in a lazy list (such as `SliverList`) once it has been
/// built, so scrolling it out of view and back keeps its state: a half-typed
/// message, a loaded conversation, an open panel.
///
/// The child is still built only when it first comes near the viewport.
class KeepAliveBlock extends StatefulWidget {
  final Widget child;

  const KeepAliveBlock({super.key, required this.child});

  @override
  State<KeepAliveBlock> createState() => _KeepAliveBlockState();
}

class _KeepAliveBlockState extends State<KeepAliveBlock>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
