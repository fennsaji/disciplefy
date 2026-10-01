import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/system_config_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/share_links.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../core/widgets/upgrade_dialog.dart';
import '../../../gamification/presentation/bloc/gamification_bloc.dart';
import '../../../gamification/presentation/bloc/gamification_event.dart';
import '../../../memory_verses/presentation/bloc/memory_verse_bloc.dart';
import '../../../memory_verses/presentation/bloc/memory_verse_event.dart';
import '../../../memory_verses/presentation/bloc/memory_verse_state.dart';
import '../../../tokens/presentation/bloc/token_bloc.dart';
import '../../../tokens/presentation/bloc/token_state.dart';
import '../../domain/entities/daily_verse_entity.dart';
import '../bloc/daily_verse_state.dart';

/// Translation abbreviation for in-context citation.
/// English = Berean Standard Bible (BSB); Hindi/Malayalam = Indian Revised
/// Version (IRV).
String dailyVerseTranslationAbbr(VerseLanguage language) {
  switch (language) {
    case VerseLanguage.english:
      return 'BSB';
    case VerseLanguage.hindi:
    case VerseLanguage.malayalam:
      return 'IRV';
  }
}

/// The share/copy message for the loaded daily verse: cited reference, text
/// and the daily-verse deep link.
String dailyVerseShareMessage(DailyVerseLoaded state) {
  final ref = state.verse.getReferenceText(state.currentLanguage);
  final abbr = dailyVerseTranslationAbbr(state.currentLanguage);
  return ShareLinks.verseMessage(
    citedReference: '$ref ($abbr)',
    verseText: state.currentVerseText,
    link: ShareLinks.dailyVerse,
  );
}

/// The three verse actions the app has always offered on the home verse:
/// copy, share and add to memory. Refresh is deliberately not here; it only
/// appears in the error state, where a retry is the one thing to do.
///
/// [iconColor] is white on the hero scene; [compact] shrinks the Material
/// 48px touch target so the row does not become the tallest thing on screen.
class DailyVerseActions extends StatelessWidget {
  final DailyVerseLoaded state;
  final Color iconColor;
  final double iconSize;
  final double gap;

  const DailyVerseActions({
    super.key,
    required this.state,
    this.iconColor = Colors.white,
    this.iconSize = 20,
    this.gap = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _copy(context),
          icon: Icon(Icons.copy_outlined, color: iconColor, size: iconSize),
          tooltip: context.tr(TranslationKeys.dailyVerseCopy),
          style: dailyVerseActionButtonStyle,
        ),
        SizedBox(width: gap),
        IconButton(
          onPressed: () => Share.share(dailyVerseShareMessage(state)),
          icon: Icon(Icons.share_outlined, color: iconColor, size: iconSize),
          tooltip: context.tr(TranslationKeys.dailyVerseShare),
          style: dailyVerseActionButtonStyle,
        ),
        SizedBox(width: gap),
        AddToMemoryButton(
          verseState: state,
          iconColor: iconColor,
          iconSize: iconSize,
        ),
      ],
    );
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: dailyVerseShareMessage(state)));

    showAppSnackBar(
      context,
      context.tr(TranslationKeys.dailyVerseCopied),
      tone: AppSnackTone.success,
    );
  }
}

/// Self-contained button that adds the daily verse to the memory deck.
///
/// Uses local [_isLoading] state so the spinner appears **immediately** on
/// tap, without relying on BLoC state-transition timing.
class AddToMemoryButton extends StatefulWidget {
  final DailyVerseLoaded verseState;
  final Color iconColor;
  final double iconSize;

  const AddToMemoryButton({
    super.key,
    required this.verseState,
    this.iconColor = Colors.white,
    this.iconSize = 20,
  });

  @override
  State<AddToMemoryButton> createState() => _AddToMemoryButtonState();
}

class _AddToMemoryButtonState extends State<AddToMemoryButton> {
  bool _isLoading = false;

  void _onTap() {
    final tokenState = sl<TokenBloc>().state;
    final userPlan = tokenState is TokenLoaded
        ? tokenState.tokenStatus.userPlan.name
        : 'free';

    final configService = sl<SystemConfigService>();
    if (!configService.isFeatureEnabled('memory_verses', userPlan)) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => UpgradeDialog(
          featureKey: 'memory_verses',
          currentPlan: userPlan,
          requiredPlans: configService.getRequiredPlans('memory_verses'),
          upgradePlan: configService.getUpgradePlan('memory_verses', userPlan),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // The screen's own bloc (home provides one). MemoryVerseBloc is a DI
    // *factory*: sl<MemoryVerseBloc>() would add the verse through a
    // throwaway instance, and home's due count would never hear about it.
    final memoryVerseBloc = context.read<MemoryVerseBloc>();
    memoryVerseBloc.add(AddVerseFromDaily(
      widget.verseState.verse.id,
      language: widget.verseState.currentLanguage.code,
    ));

    final subscription = memoryVerseBloc.stream.listen((state) {
      if (state is VerseAdded) {
        // VerseAdded replaces the due list in the bloc's state; reload it so
        // the due count and the "already added" check see the new verse.
        memoryVerseBloc.add(const LoadDueVerses(forceRefresh: true));
        if (mounted) {
          setState(() => _isLoading = false);
          _showAddedSnackBar();
          sl<GamificationBloc>().add(const CheckMemoryAchievements());
        }
      } else if (state is MemoryVerseError) {
        memoryVerseBloc.add(const LoadDueVerses());
        if (mounted) {
          setState(() => _isLoading = false);
          if (state.code == 'VERSE_ALREADY_EXISTS') {
            _showAlreadyExistsSnackBar();
          } else {
            _showErrorSnackBar();
          }
        }
      } else if (state is OperationQueued) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showQueuedSnackBar(state.message);
        }
      }
    });

    // Safety timeout — cancel listener and clear spinner after 10 s.
    Future.delayed(const Duration(seconds: 10), () {
      subscription.cancel();
      if (mounted && _isLoading) setState(() => _isLoading = false);
    });
  }

  void _showAddedSnackBar() {
    showAppSnackBar(
      context,
      context.tr(TranslationKeys.memoryAddFeedbackAdded),
      tone: AppSnackTone.success,
      actionLabel: context.tr(TranslationKeys.memoryAddFeedbackReviewNow),
      onAction: () => GoRouter.of(context).go(AppRoutes.memoryVerses),
    );
  }

  void _showErrorSnackBar() {
    showAppSnackBar(
      context,
      context.tr(TranslationKeys.commonErrorTryAgain),
      tone: AppSnackTone.error,
    );
  }

  void _showAlreadyExistsSnackBar() {
    showAppSnackBar(
      context,
      context.tr(TranslationKeys.memoryAddFeedbackAlreadyExists),
      tone: AppSnackTone.warning,
      actionLabel: context.tr(TranslationKeys.memoryAddFeedbackReview),
      onAction: () => GoRouter.of(context).go(AppRoutes.memoryVerses),
    );
  }

  void _showQueuedSnackBar(String message) {
    showAppSnackBar(context, message, tone: AppSnackTone.warning);
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.iconColor;
    if (_isLoading) {
      return SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
            ),
          ),
        ),
      );
    }

    return BlocBuilder<MemoryVerseBloc, MemoryVerseState>(
      // Only a loaded due list answers "is it already added?"; transient
      // states (adding, reloading) keep the last answer instead of flashing.
      buildWhen: (_, current) => current is DueVersesLoaded,
      builder: (context, memoryState) {
        final isAlreadyInMemory = memoryState is DueVersesLoaded &&
            memoryState.verses.any((v) =>
                v.sourceId == widget.verseState.verse.id &&
                v.language == widget.verseState.currentLanguage.code);

        return IconButton(
          onPressed: isAlreadyInMemory ? null : _onTap,
          icon: isAlreadyInMemory
              ? Icon(
                  Icons.psychology_rounded,
                  color: iconColor.withValues(alpha: 0.5),
                  size: widget.iconSize,
                )
              : Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      color: iconColor,
                      size: widget.iconSize,
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Text(
                        '+',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: iconColor.withValues(alpha: 0.85),
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
          tooltip: isAlreadyInMemory
              ? context.tr(TranslationKeys.dailyVerseAlreadyInMemory)
              : context.tr(TranslationKeys.dailyVerseAddToMemory),
          style: dailyVerseActionButtonStyle,
        );
      },
    );
  }
}

/// Compact icon buttons for the verse action row. Material pads an
/// IconButton to a 48px touch target on phones, which made this row the
/// tallest thing in the old card; 36px with a shrink-wrapped target keeps the
/// icons easy to hit without the extra band of empty space.
final ButtonStyle dailyVerseActionButtonStyle = IconButton.styleFrom(
  minimumSize: const Size(36, 36),
  padding: const EdgeInsets.all(6),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  visualDensity: VisualDensity.compact,
);
