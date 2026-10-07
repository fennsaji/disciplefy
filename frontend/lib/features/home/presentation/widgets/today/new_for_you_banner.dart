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
/// title, one line of detail, a 32px white pill and a dismiss ×.
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
          title,
          style: AppFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: onPhoto.text,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AppFonts.inter(
            fontSize: 12,
            color: onPhoto.text.withValues(alpha: 0.86),
            height: 1.35,
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
        padding: const EdgeInsets.symmetric(horizontal: 14),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
        textStyle: AppFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      child: Text(context.tr(TranslationKeys.nfyBannerCta(name))),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: Image.asset(
                newForYouPhotos[kind]!,
                fit: BoxFit.cover,
                cacheWidth: 720,
                errorBuilder: (_, __, ___) => ColoredBox(color: onPhoto.card),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.88),
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: onPhoto.hairline),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 4, 12),
            child: LayoutBuilder(builder: (context, box) {
              final stacked = box.maxWidth < _stackedBelow;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr(TranslationKeys.nfyEyebrow).toUpperCase(),
                          style: AppFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: onPhoto.gold,
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: context.tr(TranslationKeys.nfyDismiss),
                        excludeSemantics: true,
                        child: InkResponse(
                          onTap: onDismiss,
                          radius: 20,
                          child: SizedBox(
                            width: 40,
                            height: 32,
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: onPhoto.text.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: stacked
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              text,
                              const SizedBox(height: 10),
                              cta,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(child: text),
                              const SizedBox(width: 12),
                              cta,
                            ],
                          ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
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
