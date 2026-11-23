import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

/// Écran de démarrage : logo qui apparaît en douceur.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.7, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutBack,
          builder: (_, v, child) => Opacity(opacity: ((v - 0.7) / 0.3).clamp(0, 1), child: Transform.scale(scale: v, child: child)),
          child: const BallalLogo(size: 52),
        ),
      ),
    );
  }
}

/// Vague bleue en haut des écrans d'accueil (comme sur la maquette).
class BallalWave extends StatelessWidget {
  const BallalWave({super.key, required this.height, this.child});
  final double height;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(fit: StackFit.expand, children: [
        ClipPath(
          clipper: _WaveClipper(),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE8F0FF), Color(0xFFD6E4FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Positioned(
          right: -60,
          top: -40,
          child: Container(
            width: 220,
            height: 220,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [BallalColors.primary, BallalColors.primaryDark]),
            ),
          ),
        ),
        Positioned(
          right: 40,
          top: 120,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(shape: BoxShape.circle, color: BallalColors.accent.withValues(alpha: 0.9)),
          ),
        ),
        if (child != null) child!,
      ]),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path()..lineTo(0, size.height - 40);
    p.quadraticBezierTo(size.width * 0.25, size.height, size.width * 0.55, size.height - 30);
    p.quadraticBezierTo(size.width * 0.85, size.height - 60, size.width, size.height - 20);
    p.lineTo(size.width, 0);
    return p..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await Session.instance.markOnboardingSeen();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pages = [
      (const ['business'], l.onb1Title, l.onb1Tagline),
      (const ['plumber', 'builder'], l.onb2Title, l.onb2Text),
      (const ['beauty', 'chef', 'doctor', 'delivery'], l.onb3Title, l.onb3Text),
    ];
    final last = _page == pages.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
            child: Row(children: [
              const BallalLogo(size: 30),
              const Spacer(),
              if (!last) TextButton(onPressed: _finish, child: Text(l.skip)),
            ]),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final (people, title, text) = pages[i];
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final pos = _controller.hasClients && _controller.position.haveDimensions
                        ? (_controller.page ?? 0) - i
                        : 0.0;
                    return Opacity(
                      opacity: (1 - pos.abs()).clamp(0.0, 1.0),
                      child: Transform.translate(offset: Offset(pos * -60, 0), child: child),
                    );
                  },
                  child: Column(children: [
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(title,
                          style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: BallalColors.primaryDark, height: 1.2)),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(text, style: const TextStyle(fontSize: 15, color: BallalColors.primary, height: 1.4, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: _PeopleStage(people: people)),
                  ]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? BallalColors.primary : BallalColors.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: last
                    ? _finish
                    : () => _controller.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(last ? l.start : l.next),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Personnages détourés posés sur un disque dégradé bleu/orange.
class _PeopleStage extends StatelessWidget {
  const _PeopleStage({required this.people});
  final List<String> people;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final h = c.maxHeight;
      return Stack(alignment: Alignment.bottomCenter, children: [
        Positioned(
          bottom: 0,
          child: Container(
            width: c.maxWidth * 0.95,
            height: h * 0.78,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(400)),
              gradient: LinearGradient(
                colors: [BallalColors.primarySoft, Color(0xFFFFE7D3)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < people.length; i++)
              Flexible(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 500 + i * 120),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, child) => Opacity(
                    opacity: v,
                    child: Transform.translate(offset: Offset(0, 40 * (1 - v)), child: child),
                  ),
                  child: Image.asset(
                    'assets/people/${people[i]}.png',
                    height: people.length == 1 ? h * 0.95 : (people.length == 2 ? h * 0.85 : h * 0.62),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
          ],
        ),
      ]);
    });
  }
}
