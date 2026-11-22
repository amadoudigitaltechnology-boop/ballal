import 'package:flutter/material.dart';

/// Palette tirée des maquettes BALLAL (bleu confiance + orange énergie).
class BallalColors {
  static const primary = Color(0xFF1A56DB);
  static const primaryDark = Color(0xFF0B2A6F);
  static const primarySoft = Color(0xFFE8F0FF);
  static const accent = Color(0xFFFF7A1A);
  static const accentSoft = Color(0xFFFFF1E6);
  static const bg = Color(0xFFF5F7FB);
  static const surface = Colors.white;
  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
  static const star = Color(0xFFF5A623);
}

const kRadius = 16.0;

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
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
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
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(BallalColors.border),
      enabledBorder: border(BallalColors.border),
      focusedBorder: border(BallalColors.primary, 1.5),
      errorBorder: border(BallalColors.danger),
      hintStyle: const TextStyle(color: BallalColors.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
        side: const BorderSide(color: BallalColors.border),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dividerTheme: const DividerThemeData(color: BallalColors.border, space: 1, thickness: 1),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Carte blanche arrondie utilisée partout.
class BallalCard extends StatelessWidget {
  const BallalCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.margin});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
