import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/home/domain/new_for_you/feature_intro_content.dart';
import 'package:disciplefy_bible_study/features/home/domain/new_for_you/new_for_you_scheduler.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/new_for_you_cubit.dart';

/// Below this width the call to action moves under the text so hi/ml copy
/// keeps room to wrap.
const double _stackedBelow = 300;

/// Photo banner that introduces one feature: gold "New for you" eyebrow,
/// title, one line of detail, a 32px white pill and a dismiss ×, on a
/// 110px photo card.
///
/// The photo sits under a dark scrim in both themes, so the text uses the
/// dark-surface tokens: at its lightest the scrim is 72% black, which keeps
/// the detail line well above 4.5:1 even over a white patch of photo.
class NewForYouBanner extends StatelessWidget {
  final NewForYouKind kind;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  /// Today's verse reference for the memory banner ("Practise {ref}…").
  final String? verseReference;

  /// The active path's title for the fellowships banner ("Study {path}…").
  final String? pathTitle;

  const NewForYouBanner({
    super.key,
    required this.kind,
    required this.onOpen,
    required this.onDismiss,
    this.verseReference,
    this.pathTitle,
  });

  String _subtitle(BuildContext context) {
    final name = kind.name;
    final ref = verseReference?.trim() ?? '';
    final path = pathTitle?.trim() ?? '';
    return switch (kind) {
      NewForYouKind.memory => ref.isEmpty
          ? context.tr(TranslationKeys.nfyBannerSubAny(name))
          : context.tr(TranslationKeys.nfyBannerSub(name), {'ref': ref}),
      NewForYouKind.fellowships => path.isEmpty
          ? context.tr(TranslationKeys.nfyBannerSubAny(name))
          : context.tr(TranslationKeys.nfyBannerSub(name), {'path': path}),
      _ => context.tr(TranslationKeys.nfyBannerSub(name)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final onPhoto = ReaderPalette.resolve(
      isDark: true,
      page: Theme.of(context).scaffoldBackgroundColor,
    );
    final name = kind.name;
    final title = context.tr(TranslationKeys.nfyBannerTitle(name));
    final subtitle = _subtitle(context);

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.tr(TranslationKeys.nfyEyebrow).toUpperCase(),
          style: AppFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
            color: onPhoto.gold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: AppFonts.inter(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: onPhoto.text,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AppFonts.inter(
            fontSize: 12,
            color: const Color(0xFFD6D6DC),
            height: 1.25,
          ),
        ),
      ],
    );

    final cta = FilledButton(
      onPressed: onOpen,
      style: FilledButton.styleFrom(
        backgroundColor: onPhoto.ctaFill,
        foregroundColor: onPhoto.ctaInk,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
        textStyle: AppFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
      child: Text(context.tr(TranslationKeys.nfyBannerCta(name))),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 1.6, sigmaY: 1.6),
                child: Image.asset(
                  newForYouPhotos[kind]!,
                  fit: BoxFit.cover,
                  cacheWidth: 720,
                  errorBuilder: (_, __, ___) => ColoredBox(color: onPhoto.card),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                // The design's scrim: near-black on the text side, opening up
                // toward the action so the photo shows on the right.
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0B0B0B).withValues(alpha: 0.97),
                    const Color(0xFF0B0B0B).withValues(alpha: 0.88),
                    const Color(0xFF0B0B0B).withValues(alpha: 0.60),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 110),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: LayoutBuilder(builder: (context, box) {
                if (box.maxWidth < _stackedBelow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Room for the × at the top right.
                      Padding(
                        padding: const EdgeInsets.only(right: 28),
                        child: text,
                      ),
                      const SizedBox(height: 10),
                      cta,
                    ],
                  );
                }
                // Text centred on the left; the action at the bottom right,
                // under the ×.
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // The ×'s row, so the action never sits under it.
                          const SizedBox(height: 32),
                          cta,
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          // The ×: a 40px square to tap, its icon 19px in from the corner.
          Positioned(
            top: 0,
            right: 0,
            child: Semantics(
              button: true,
              label: context.tr(TranslationKeys.nfyDismiss),
              excludeSemantics: true,
              child: InkResponse(
                key: const Key('nfy_dismiss'),
                onTap: onDismiss,
                radius: 20,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: onPhoto.text.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const double _radius = 18;
}

/// The banner chosen by [NewForYouCubit], or nothing.
///
/// Opening it marks the kind done and opens its introduction; × dismisses
/// it for good. The cubit must be provided above (and loaded) by Home.
class NewForYouSection extends StatelessWidget {
  final String? verseReference;
  final String? pathTitle;

  const NewForYouSection({super.key, this.verseReference, this.pathTitle});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NewForYouCubit, NewForYouKind?>(
      builder: (context, kind) {
        if (kind == null) return const SizedBox.shrink();
        return NewForYouBanner(
          kind: kind,
          verseReference: verseReference,
          pathTitle: pathTitle,
          onOpen: () {
            context.read<NewForYouCubit>().opened();
            context.push(AppRoutes.featureIntroFor(kind.name));
          },
          onDismiss: () => context.read<NewForYouCubit>().dismiss(),
        );
      },
    );
  }
}
