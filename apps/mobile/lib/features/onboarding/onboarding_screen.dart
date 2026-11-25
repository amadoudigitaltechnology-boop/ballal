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
      (const ['builder', 'doctor'], l.onb2Title, l.onb2Text),
      (const ['beauty', 'chef', 'delivery'], l.onb3Title, l.onb3Text),
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
                          style: displayStyle(28, color: BallalColors.primaryDark)),
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

/// Photos entières dans des cadres arrondis (pas de détourage : rendu naturel).
class _PeopleStage extends StatelessWidget {
  const _PeopleStage({required this.people});
  final List<String> people;

  @override
  Widget build(BuildContext context) {
    Widget photo(String name, int i) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 450 + i * 120),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => Opacity(opacity: v, child: Transform.scale(scale: 0.92 + 0.08 * v, child: child)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: BallalColors.primary.withValues(alpha: 0.18), blurRadius: 22, offset: const Offset(0, 10))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(fit: StackFit.expand, children: [
                Image.asset('assets/people/$name.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x330B2A6F)],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: switch (people.length) {
        1 => photo(people[0], 0),
        2 => Row(children: [
            Expanded(child: photo(people[0], 0)),
            const SizedBox(width: 12),
            Expanded(child: Padding(padding: const EdgeInsets.only(top: 36), child: photo(people[1], 1))),
          ]),
        _ => Column(children: [
            Expanded(child: Row(children: [
              Expanded(child: photo(people[0], 0)),
              const SizedBox(width: 12),
              Expanded(child: photo(people[1], 1)),
            ])),
            const SizedBox(height: 12),
            Expanded(child: Row(children: [
              Expanded(child: photo(people[2], 2)),
              const SizedBox(width: 12),
              Expanded(child: photo(people[3], 3)),
            ])),
          ]),
      },
    );
  }
}
