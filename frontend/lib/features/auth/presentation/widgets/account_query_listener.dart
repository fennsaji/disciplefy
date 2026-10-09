import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_needed_sheet.dart';

/// Opens the account-needed sheet for Home's `?account=<reason>` (set by the
/// guest route gate and the Memory Verses pill), then clears the query.
///
/// Each value opens the sheet once: rebuilds with the same value do nothing,
/// and the query is cleared when the sheet closes.
class AccountQueryListener extends StatefulWidget {
  /// The raw `account` query value, or null.
  final String? reason;
  final Widget child;

  /// Clears the query. Defaults to going to [AppRoutes.home].
  final void Function(BuildContext context)? onClear;

  const AccountQueryListener({
    super.key,
    required this.reason,
    required this.child,
    this.onClear,
  });

  @override
  State<AccountQueryListener> createState() => _AccountQueryListenerState();
}

class _AccountQueryListenerState extends State<AccountQueryListener> {
  /// The value already handled; reset once the query is gone.
  String? _handled;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(covariant AccountQueryListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    _check();
  }

  void _check() {
    final value = widget.reason;
    // A blank value (`?account=%20`) has no reason: treat it as no query.
    final reason = AccountReason.fromWire(value);
    if (value == null || reason == null) {
      _handled = null;
      return;
    }
    if (value == _handled) return;
    _handled = value;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await requireAccount(context, reason);
      if (!mounted) return;
      // Only clear while the query is still the one handled here.
      if (widget.reason != value) return;
      final clear = widget.onClear;
      if (clear != null) {
        clear(context);
      } else {
        GoRouter.maybeOf(context)?.go(AppRoutes.home);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
