import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../connectivity/connectivity_bloc.dart';
import '../constants/app_fonts.dart';
import '../extensions/translation_extension.dart';
import '../i18n/translation_keys.dart';
import '../theme/app_colors.dart';
import '../theme/reader_palette.dart';

/// Slim connectivity strip at the top of the app shell: amber "offline"
/// while disconnected, then a brief green "back online" once reconnected.
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
                ? _BannerStrip(isOffline: isOffline)
                : const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}

/// Raised palette strip with a tinted status icon and muted Inter text.
/// Sits under the status bar, so it pads itself by the top inset.
class _BannerStrip extends StatelessWidget {
  final bool isOffline;

  const _BannerStrip({required this.isOffline});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final (IconData icon, Color tint) = isOffline
        ? (
            Icons.cloud_off_rounded,
            palette.isDark ? AppColors.warning : AppColors.warningDark,
          )
        : (
            Icons.cloud_done_rounded,
            palette.isDark ? AppColors.success : AppColors.successDark,
          );
    final label = context.tr(isOffline
        ? TranslationKeys.appChromeOfflineOffline
        : TranslationKeys.appChromeOfflineBackOnline);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
            16, MediaQuery.paddingOf(context).top + 6, 16, 6),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            tint.withValues(alpha: palette.isDark ? 0.14 : 0.1),
            palette.raised,
          ),
          border: Border(bottom: BorderSide(color: palette.hairline)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: tint),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: palette.text,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
