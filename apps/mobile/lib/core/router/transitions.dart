import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Smooth fade-through page transition (used for onboarding steps + the
/// reveal screen — they're "deeper levels", not lateral navigation).
CustomTransitionPage<T> fadeThrough<T>({
  required LocalKey? key,
  required Widget child,
  Duration duration = const Duration(milliseconds: 320),
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondary, child) {
      final fadeIn = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.35, 1, curve: Curves.easeOut),
        reverseCurve: const Interval(0, 0.4, curve: Curves.easeIn),
      );
      final fadeOut = CurvedAnimation(
        parent: secondary,
        curve: const Interval(0, 0.5, curve: Curves.easeIn),
        reverseCurve: const Interval(0.5, 1, curve: Curves.easeOut),
      );
      return FadeTransition(
        opacity: ReverseAnimation(fadeOut),
        child: FadeTransition(
          opacity: fadeIn,
          child: child,
        ),
      );
    },
  );
}

/// Slide-up modal transition (camera, share — they enter from the bottom
/// and feel modal).
CustomTransitionPage<T> slideUp<T>({
  required LocalKey? key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondary, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ));
      return SlideTransition(position: slide, child: child);
    },
  );
}
