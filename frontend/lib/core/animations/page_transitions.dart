import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_animations.dart';

/// Custom page transitions for GoRouter
///
/// Provides consistent, smooth page transitions throughout the app.

/// Creates a fade + slide from bottom transition
CustomTransitionPage<T> fadeSlideTransitionPage<T>({
  required Widget child,
  required GoRouterState state,
  Duration? duration,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration ?? AppAnimations.slow,
    reverseTransitionDuration: duration ?? AppAnimations.medium,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Check for reduced motion
      if (AppAnimations.shouldReduceMotion(context)) {
        return child;
      }

      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: AppAnimations.defaultCurve,
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.05),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: AppAnimations.defaultCurve,
          )),
          child: child,
        ),
      );
    },
  );
}

/// Creates a slide from right transition (for push navigation)
CustomTransitionPage<T> slideRightTransitionPage<T>({
  required Widget child,
  required GoRouterState state,
  Duration? duration,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration ?? AppAnimations.slow,
    reverseTransitionDuration: duration ?? AppAnimations.medium,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (AppAnimations.shouldReduceMotion(context)) {
        return child;
      }

      final slideAnimation = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: AppAnimations.defaultCurve,
      ));

      final fadeAnimation = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      );

      return FadeTransition(
        opacity: fadeAnimation,
        child: SlideTransition(
          position: slideAnimation,
          child: child,
        ),
      );
    },
  );
}

/// Creates a slide from bottom transition (for modal-like pages)
CustomTransitionPage<T> slideUpTransitionPage<T>({
  required Widget child,
  required GoRouterState state,
  Duration? duration,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration ?? AppAnimations.slow,
    reverseTransitionDuration: duration ?? AppAnimations.medium,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (AppAnimations.shouldReduceMotion(context)) {
        return child;
      }

      final slideAnimation = Tween<Offset>(
        begin: const Offset(0.0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: AppAnimations.defaultCurve,
      ));

      final fadeAnimation = CurvedAnimation(
        parent: animation,
        curve: AppAnimations.defaultCurve,
      );

      return FadeTransition(
        opacity: fadeAnimation,
        child: SlideTransition(
          position: slideAnimation,
          child: child,
        ),
      );
    },
  );
}

/// Creates a fade-only transition (for tab-like switches)
CustomTransitionPage<T> fadeTransitionPage<T>({
  required Widget child,
  required GoRouterState state,
  Duration? duration,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration ?? AppAnimations.medium,
    reverseTransitionDuration: duration ?? AppAnimations.fast,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (AppAnimations.shouldReduceMotion(context)) {
        return child;
      }

      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: AppAnimations.defaultCurve,
        ),
        child: child,
      );
    },
  );
}

/// Creates a scale + fade transition (for modals/dialogs)
CustomTransitionPage<T> scaleTransitionPage<T>({
  required Widget child,
  required GoRouterState state,
  Duration? duration,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration ?? AppAnimations.medium,
    reverseTransitionDuration: duration ?? AppAnimations.fast,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (AppAnimations.shouldReduceMotion(context)) {
        return child;
      }

      final scaleAnimation = Tween<double>(
        begin: 0.9,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: AppAnimations.bounceCurve,
      ));

      final fadeAnimation = CurvedAnimation(
        parent: animation,
        curve: AppAnimations.defaultCurve,
      );

      return FadeTransition(
        opacity: fadeAnimation,
        child: ScaleTransition(
          scale: scaleAnimation,
          child: child,
        ),
      );
    },
  );
}
