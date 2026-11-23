import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/supa.dart';
import '../core/theme.dart';

/// Célébration « Votre compte a été créé avec succès » : cercle qui se dessine, coche, confettis.
Future<void> showAccountCreated(BuildContext context, String firstName) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: BallalColors.primaryDark.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (ctx, _, __) => _AccountCreated(firstName: firstName),
    transitionBuilder: (_, a, __, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
        child: child,
      ),
    ),
  );
}

class _AccountCreated extends StatefulWidget {
  const _AccountCreated({required this.firstName});
  final String firstName;

  @override
  State<_AccountCreated> createState() => _AccountCreatedState();
}

class _AccountCreatedState extends State<_AccountCreated> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  bool _closed = false;

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 3000), _close);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [BoxShadow(color: BallalColors.primary.withValues(alpha: 0.3), blurRadius: 40, offset: const Offset(0, 20))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 160,
              height: 160,
              child: AnimatedBuilder(animation: _c, builder: (_, __) => CustomPaint(painter: _SuccessPainter(_c.value))),
            ),
            const SizedBox(height: 10),
            Text(l.accountCreatedTitle, textAlign: TextAlign.center, style: displayStyle(21, color: BallalColors.primaryDark)),
            const SizedBox(height: 8),
            Text(l.accountCreatedText(widget.firstName),
                textAlign: TextAlign.center, style: const TextStyle(color: BallalColors.muted, height: 1.4)),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: _close, child: Text(l.continueLabel))),
          ]),
        ),
      ),
    );
  }
}

class _SuccessPainter extends CustomPainter {
  _SuccessPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.3;

    // Confettis qui jaillissent autour du cercle.
    const colors = [BallalColors.primary, BallalColors.accent, Color(0xFF22C55E), Color(0xFFFFC107)];
    final burst = Curves.easeOut.transform(((t - 0.35) / 0.65).clamp(0.0, 1.0));
    if (burst > 0) {
      for (var i = 0; i < 16; i++) {
        final ang = i * 2 * math.pi / 16 + (i.isEven ? 0.1 : -0.1);
        final dist = r * (1.1 + (i.isEven ? 0.6 : 0.45) * burst);
        final p = c + Offset(dist * math.cos(ang), dist * math.sin(ang));
        final paint = Paint()..color = colors[i % 4].withValues(alpha: 1 - burst * 0.55);
        if (i % 3 == 0) {
          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate(ang + burst * 3);
          canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -2, 10, 4), const Radius.circular(2)), paint);
          canvas.restore();
        } else {
          canvas.drawCircle(p, 4.2 * (1 - burst * 0.35), paint);
        }
      }
    }

    // Cercle dégradé qui se dessine.
    final circle = Curves.easeOutCubic.transform((t / 0.45).clamp(0.0, 1.0));
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(c, r, Paint()..color = BallalColors.primarySoft.withValues(alpha: circle));
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * circle,
      false,
      Paint()
        ..shader = kBrandGradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );

    // Coche qui se trace.
    final check = ((t - 0.4) / 0.4).clamp(0.0, 1.0);
    if (check > 0) {
      final path = ui.Path()
        ..moveTo(c.dx - r * 0.42, c.dy + r * 0.02)
        ..lineTo(c.dx - r * 0.1, c.dy + r * 0.34)
        ..lineTo(c.dx + r * 0.46, c.dy - r * 0.3);
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * Curves.easeOutCubic.transform(check)),
        Paint()
          ..color = BallalColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SuccessPainter old) => old.t != t;
}
