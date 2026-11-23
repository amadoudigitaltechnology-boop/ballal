import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Illustration du front de mer de Conakry (dessinée, sans image) : ciel, immeubles, monument,
/// palmiers, mer et vagues aux couleurs BALLAL. Les vagues ondulent doucement.
class ConakrySkyline extends StatefulWidget {
  const ConakrySkyline({super.key, this.height = 260});
  final double height;

  @override
  State<ConakrySkyline> createState() => _ConakrySkylineState();
}

class _ConakrySkylineState extends State<ConakrySkyline> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(animation: _c, builder: (_, __) => CustomPaint(painter: _SkylinePainter(_c.value))),
    );
  }
}

class _SkylinePainter extends CustomPainter {
  _SkylinePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.62;

    // Ciel
    final sky = Rect.fromLTWH(0, 0, w, horizon);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00FFFFFF), Color(0xFFDDE9FF), Color(0xFFC7DBFF)],
          stops: [0, 0.55, 1],
        ).createShader(sky),
    );

    // Immeubles lointains
    final far = Paint()..color = const Color(0xFF9DB8EA);
    final rnd = math.Random(7);
    var x = 0.0;
    while (x < w) {
      final bw = 14 + rnd.nextDouble() * 22;
      final bh = 18 + rnd.nextDouble() * 46;
      canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(x, horizon - bh, bw, bh), topLeft: const Radius.circular(2), topRight: const Radius.circular(2)), far);
      x += bw + 2;
    }
    // Immeubles proches avec fenêtres
    final near = Paint()..color = const Color(0xFF5E86D6);
    final win = Paint()..color = Colors.white.withValues(alpha: 0.55);
    x = w * 0.52;
    final rnd2 = math.Random(3);
    while (x < w) {
      final bw = 18 + rnd2.nextDouble() * 20;
      final bh = 40 + rnd2.nextDouble() * 60;
      final r = Rect.fromLTWH(x, horizon - bh, bw, bh);
      canvas.drawRect(r, near);
      for (var wy = r.top + 6; wy < r.bottom - 6; wy += 9) {
        for (var wx = r.left + 4; wx < r.right - 4; wx += 7) {
          canvas.drawRect(Rect.fromLTWH(wx, wy, 3, 4), win);
        }
      }
      x += bw + 4;
    }

    // Monument (arche élancée) à gauche
    final mx = w * 0.26;
    final mBase = horizon;
    final mTop = horizon - h * 0.5;
    final mon = Paint()
      ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF5F7FB), Color(0xFFBFCBE0)])
          .createShader(Rect.fromLTWH(mx - 40, mTop, 80, mBase - mTop));
    final arch = ui.Path()
      ..moveTo(mx - 38, mBase)
      ..quadraticBezierTo(mx - 20, mTop + 40, mx - 3, mTop)
      ..lineTo(mx + 3, mTop)
      ..quadraticBezierTo(mx + 20, mTop + 40, mx + 38, mBase)
      ..lineTo(mx + 28, mBase)
      ..quadraticBezierTo(mx + 12, mTop + 70, mx, mTop + 36)
      ..quadraticBezierTo(mx - 12, mTop + 70, mx - 28, mBase)
      ..close();
    canvas.drawPath(arch, mon);
    canvas.drawPath(arch, Paint()
      ..color = const Color(0xFF8FA3C4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
    canvas.drawRect(Rect.fromLTWH(mx - 46, mBase - 6, 92, 6), Paint()..color = const Color(0xFFD5DEEC));

    // Palmiers
    void palm(double px, double ph) {
      final trunk = Paint()
        ..color = const Color(0xFF3B5B4A)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final top = Offset(px + 6, horizon - ph);
      canvas.drawPath(ui.Path()
        ..moveTo(px, horizon)
        ..quadraticBezierTo(px + 2, horizon - ph / 2, top.dx, top.dy), trunk);
      final leaf = Paint()..color = const Color(0xFF2F8F5B);
      for (var i = 0; i < 6; i++) {
        final a = -math.pi + i * math.pi / 5;
        final end = top + Offset(math.cos(a) * 16, math.sin(a) * 9 + 6);
        canvas.drawPath(
            ui.Path()
              ..moveTo(top.dx, top.dy)
              ..quadraticBezierTo((top.dx + end.dx) / 2, top.dy - 6, end.dx, end.dy)
              ..quadraticBezierTo((top.dx + end.dx) / 2, top.dy, top.dx, top.dy),
            leaf);
      }
    }

    palm(w * 0.06, 46);
    palm(w * 0.44, 38);
    palm(w * 0.5, 52);

    // Quai / route
    canvas.drawRect(Rect.fromLTWH(0, horizon, w, 6), Paint()..color = const Color(0xFFE8EDF5));

    // Mer
    final sea = Rect.fromLTWH(0, horizon + 6, w, h - horizon - 6);
    canvas.drawRect(sea, Paint()
      ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF7FB2F0), Color(0xFF2F6BFF)])
          .createShader(sea));
    // Reflets
    final glint = Paint()..color = Colors.white.withValues(alpha: 0.35);
    for (var i = 0; i < 9; i++) {
      final gx = (i * 47.0 + t * 30) % w;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(gx, horizon + 14 + (i % 3) * 8, 18, 2), const Radius.circular(2)), glint);
    }

    // Vagues signature (orange + bleu nuit) qui ondulent
    ui.Path wave(double base, double amp, double phase) {
      final p = ui.Path()..moveTo(0, h);
      p.lineTo(0, base);
      for (var px = 0.0; px <= w; px += 6) {
        p.lineTo(px, base + math.sin(px / w * 2 * math.pi + phase) * amp);
      }
      p.lineTo(w, h);
      return p..close();
    }

    final ph = t * 2 * math.pi;
    canvas.drawPath(wave(h * 0.86, 7, ph), Paint()..color = BallalColors.accent);
    canvas.drawPath(wave(h * 0.9, 6, ph + 1.4), Paint()..color = BallalColors.primaryDark);
    canvas.drawPath(wave(h * 0.95, 5, ph + 2.6), Paint()..color = BallalColors.primary);
  }

  @override
  bool shouldRepaint(covariant _SkylinePainter old) => old.t != t;
}

/// Grande vague décorative en haut à droite des écrans de connexion (comme la maquette).
class CornerSwoosh extends StatelessWidget {
  const CornerSwoosh({super.key, this.size = 160});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _SwooshPainter()));
}

class _SwooshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final blue = ui.Path()
      ..moveTo(s.width * 0.25, 0)
      ..quadraticBezierTo(s.width * 0.55, s.height * 0.45, s.width, s.height * 0.55)
      ..lineTo(s.width, 0)
      ..close();
    canvas.drawPath(blue, Paint()..shader = kBrandGradient.createShader(Offset.zero & s));
    final orange = ui.Path()
      ..moveTo(s.width * 0.45, 0)
      ..quadraticBezierTo(s.width * 0.7, s.height * 0.28, s.width, s.height * 0.32)
      ..lineTo(s.width, s.height * 0.22)
      ..quadraticBezierTo(s.width * 0.75, s.height * 0.18, s.width * 0.6, 0)
      ..close();
    canvas.drawPath(orange, Paint()..color = BallalColors.accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


/// Photo aérienne de Conakry (fondue vers le blanc en haut) + vagues BALLAL animées en bas.
class ConakryPhoto extends StatefulWidget {
  const ConakryPhoto({super.key, this.height = 320});
  final double height;

  @override
  State<ConakryPhoto> createState() => _ConakryPhotoState();
}

class _ConakryPhotoState extends State<ConakryPhoto> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(fit: StackFit.expand, children: [
        ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black],
            stops: [0, 0.35],
          ).createShader(r),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.08, end: 1),
            duration: const Duration(seconds: 3),
            curve: Curves.easeOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Image.asset('assets/conakry.jpg', fit: BoxFit.cover, alignment: Alignment.center),
          ),
        ),
        AnimatedBuilder(animation: _c, builder: (_, __) => CustomPaint(painter: _WavesPainter(_c.value))),
      ]),
    );
  }
}

class _WavesPainter extends CustomPainter {
  _WavesPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    ui.Path wave(double base, double amp, double phase) {
      final p = ui.Path()..moveTo(0, h);
      p.lineTo(0, base);
      for (var px = 0.0; px <= w; px += 6) {
        p.lineTo(px, base + math.sin(px / w * 2 * math.pi + phase) * amp);
      }
      p.lineTo(w, h);
      return p..close();
    }

    final ph = t * 2 * math.pi;
    canvas.drawPath(wave(h * 0.86, 7, ph), Paint()..color = BallalColors.accent);
    canvas.drawPath(wave(h * 0.9, 6, ph + 1.4), Paint()..color = BallalColors.primaryDark);
    canvas.drawPath(wave(h * 0.95, 5, ph + 2.6), Paint()..color = BallalColors.primary);
  }

  @override
  bool shouldRepaint(covariant _WavesPainter old) => old.t != t;
}
