import 'package:flutter/material.dart';

/// Palette tirée des maquettes et du logo BALLAL (bleu confiance + orange énergie).
class BallalColors {
  static const primary = Color(0xFF1A56DB);
  static const primaryDark = Color(0xFF0B2A6F);
  static const primarySoft = Color(0xFFE8F0FF);
  static const accent = Color(0xFFFF7A1A);
  static const accentSoft = Color(0xFFFFF1E6);
  static const bg = Color(0xFFF6F8FC);
  static const field = Color(0xFFF0F3F9);
  static const surface = Colors.white;
  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
  static const star = Color(0xFFF5A623);
}

const kRadius = 18.0;

ThemeData buildBallalTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: BallalColors.primary,
    primary: BallalColors.primary,
    secondary: BallalColors.accent,
    surface: BallalColors.surface,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: BallalColors.bg,
    visualDensity: VisualDensity.standard,
  );
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: w == 0 ? BorderSide.none : BorderSide(color: c, width: w),
      );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: BallalColors.bg,
      foregroundColor: BallalColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(color: BallalColors.text, fontSize: 18, fontWeight: FontWeight.w700),
    ),
    textTheme: base.textTheme.apply(bodyColor: BallalColors.text, displayColor: BallalColors.text),
    // Champs : fond gris doux, sans contour, contour bleu seulement quand on écrit.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BallalColors.field,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: border(Colors.transparent, 0),
      enabledBorder: border(Colors.transparent, 0),
      focusedBorder: border(BallalColors.primary, 1.6),
      errorBorder: border(BallalColors.danger, 1.2),
      focusedErrorBorder: border(BallalColors.danger, 1.6),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w400),
      prefixIconColor: BallalColors.muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 54),
        shape: const StadiumBorder(),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: const StadiumBorder(),
        side: const BorderSide(color: BallalColors.border),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      side: const BorderSide(color: BallalColors.border),
      backgroundColor: Colors.white,
      selectedColor: BallalColors.primarySoft,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: BallalColors.text),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dividerTheme: const DividerThemeData(color: BallalColors.border, space: 1, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}

/// Carte blanche arrondie qui s'enfonce légèrement au toucher.
class BallalCard extends StatefulWidget {
  const BallalCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.margin});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  State<BallalCard> createState() => _BallalCardState();
}

class _BallalCardState extends State<BallalCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(kRadius),
            boxShadow: [BoxShadow(color: const Color(0xFF1A56DB).withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(kRadius),
              onTap: widget.onTap,
              onHighlightChanged: widget.onTap == null ? null : (v) => setState(() => _down = v),
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Apparition douce (fondu + léger glissement) pour les éléments de liste.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 8)) * 45;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delay),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child),
      ),
      child: child,
    );
  }
}

/// Titre de champ au-dessus de la zone de saisie (plus naturel qu'un libellé flottant).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.note});
  final String text;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4, left: 4),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        if (note != null) TextSpan(text: '  $note', style: const TextStyle(color: BallalColors.muted, fontSize: 12)),
      ])),
    );
  }
}

/// Pas de compteur « 0/120 » sous les champs : la limite reste appliquée, sans être affichée.
Widget? noCounter(BuildContext context, {required int currentLength, required bool isFocused, required int? maxLength}) =>
    null;
