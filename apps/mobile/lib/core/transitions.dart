import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Familles de transitions : chaque type d'écran a son propre mouvement,
/// pour que la navigation ne soit jamais monotone.
enum Motion {
  /// Fiche d'un pro : la carte s'agrandit (zoom + fondu).
  zoom,
  /// Conversation, détail : glisse depuis la droite avec léger parallaxe.
  slide,
  /// Formulaires (demande, profil, service) : monte depuis le bas comme une feuille.
  sheet,
  /// Réglages, listes : fondu enchaîné avec petit recul.
  fadeThrough,
  /// Écrans de réussite / connexion : apparition en profondeur (rotation 3D légère).
  depth,
  /// Accueil, présentation : fondu simple.
  fade,
}

CustomTransitionPage<void> motionPage(GoRouterState state, Widget child, Motion motion) {
  final duration = switch (motion) {
    Motion.sheet => const Duration(milliseconds: 420),
    Motion.depth => const Duration(milliseconds: 520),
    Motion.fade => const Duration(milliseconds: 260),
    _ => const Duration(milliseconds: 340),
  };
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondary, child) {
      final a = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      // L'écran qui part recule légèrement : effet de profondeur.
      final back = Tween<double>(begin: 1, end: 0.94).animate(CurvedAnimation(parent: secondary, curve: Curves.easeOut));
      Widget inner;
      switch (motion) {
        case Motion.zoom:
          inner = FadeTransition(
            opacity: a,
            child: ScaleTransition(scale: Tween<double>(begin: 0.88, end: 1).animate(a), child: child),
          );
        case Motion.slide:
          inner = SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(a),
            child: child,
          );
        case Motion.sheet:
          inner = SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart, reverseCurve: Curves.easeInCubic)),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28 * (1 - a.value))),
              child: child,
            ),
          );
        case Motion.fadeThrough:
          inner = FadeTransition(
            opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: animation, curve: const Interval(0.3, 1))),
            child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1).animate(a), child: child),
          );
        case Motion.depth:
          inner = AnimatedBuilder(
            animation: a,
            child: child,
            builder: (_, c) => Opacity(
              opacity: a.value.clamp(0.0, 1.0),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateX((1 - a.value) * math.pi / 10)
                  ..scaleByDouble(0.9 + 0.1 * a.value, 0.9 + 0.1 * a.value, 1, 1),
                child: c,
              ),
            ),
          );
        case Motion.fade:
          inner = FadeTransition(opacity: a, child: child);
      }
      return ScaleTransition(scale: back, child: inner);
    },
  );
}
