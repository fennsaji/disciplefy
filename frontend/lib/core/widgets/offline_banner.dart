import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../connectivity/connectivity_bloc.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _showReconnected = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectivityBloc, ConnectivityState>(
      listener: (context, state) {
        if (state is ConnectivityOnline && !_showReconnected) {
          setState(() => _showReconnected = true);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _showReconnected = false);
          });
        }
      },
      child: BlocBuilder<ConnectivityBloc, ConnectivityState>(
        builder: (context, state) {
          final isOffline = state is ConnectivityOffline;
          final showBanner = isOffline || _showReconnected;

          return AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: showBanner
                ? Container(
                    width: double.infinity,
                    color: isOffline
                        ? const Color(0xFFFFA000)
                        : const Color(0xFF388E3C),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      isOffline
                          ? '⚡ You\'re offline · Showing cached content'
                          : '✓ Back online · Syncing...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
