import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/skyline.dart';

/// Écran de démarrage (maquette) : logo, slogan, front de mer de Conakry, indicateur de chargement.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [
        const Positioned(left: 0, right: 0, bottom: 0, child: ConakrySkyline(height: 300)),
        SafeArea(
          child: Column(children: [
            const Spacer(flex: 2),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Opacity(
                opacity: v.clamp(0.0, 1.0),
                child: Transform.scale(scale: 0.8 + 0.2 * v, child: child),
              ),
              child: const BallalLogo(size: 54),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              index: 3,
              child: Text(l.slogan, textAlign: TextAlign.center, style: displayStyle(20, color: BallalColors.primaryDark, weight: FontWeight.w700)),
            ),
            const Spacer(flex: 5),
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
            ),
            const SizedBox(height: 36),
          ]),
        ),
      ]),
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

  Future<void> _finish(String route) async {
    await Session.instance.markOnboardingSeen();
    if (mounted) context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pages = [
      (
        'woman_phone',
        [(Icons.work_rounded, BallalColors.primary, const Alignment(0.82, -0.78)),
         (Icons.build_rounded, BallalColors.accent, const Alignment(0.92, -0.32)),
         (Icons.laptop_mac_rounded, BallalColors.primary, const Alignment(0.86, 0.14))],
        l.onbTitle1,
        l.onbText1,
      ),
      (
        'builder',
        [(Icons.verified_user_rounded, const Color(0xFF16A34A), const Alignment(-0.8, -0.7)),
         (Icons.star_rounded, BallalColors.star, const Alignment(0.82, -0.45))],
        l.onbTitle2,
        l.onbText2,
      ),
    ];
    final last = _page == pages.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final (person, icons, title, text) = pages[i];
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final pos = _controller.hasClients && _controller.position.haveDimensions ? (_controller.page ?? 0) - i : 0.0;
                    return Opacity(
                      opacity: (1 - pos.abs()).clamp(0.0, 1.0),
                      child: Transform.translate(offset: Offset(pos * -80, 0), child: child),
                    );
                  },
                  child: Column(children: [
                    Expanded(flex: 6, child: _Hero(person: person, icons: icons)),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(title, textAlign: TextAlign.center, style: displayStyle(24, color: BallalColors.primaryDark)),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Text(text,
                          textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: BallalColors.muted, height: 1.45)),
                    ),
                  ]),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pages.length + 1,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _page ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _page ? BallalColors.primary : BallalColors.border,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: last ? () => _finish('/signup') : () => _controller.nextPage(duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic),
                child: Text(last ? l.start : l.next),
              ),
            ),
          ),
          TextButton(
            onPressed: () => _finish('/login'),
            child: Text(last ? l.tabLogin : l.skip, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

/// Grande photo sur fond clair avec halo bleu et icônes de métiers qui flottent.
class _Hero extends StatefulWidget {
  const _Hero({required this.person, required this.icons});
  final String person;
  final List<(IconData, Color, Alignment)> icons;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return Stack(children: [
        // Halo + vague bleue en fond
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 0.9,
                colors: [BallalColors.primarySoft, Colors.white.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
        // Photo (fond studio clair) fondue vers le blanc en bas et sur les côtés
        Positioned.fill(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.black, Colors.transparent],
              stops: [0, 0.78, 1],
            ).createShader(r),
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (r) => const LinearGradient(
                colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
                stops: [0, 0.14, 0.86, 1],
              ).createShader(r),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, child) => Opacity(opacity: v, child: Transform.scale(scale: 0.94 + 0.06 * v, child: child)),
                child: Image.asset('assets/people/${widget.person}.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter),
              ),
            ),
          ),
        ),
        // Icônes flottantes
        for (var i = 0; i < widget.icons.length; i++)
          AnimatedBuilder(
            animation: _float,
            builder: (_, child) {
              final (icon, color, align) = widget.icons[i];
              final dy = (i.isEven ? 1 : -1) * 6 * Curves.easeInOut.transform(_float.value);
              return Align(
                alignment: align,
                child: Transform.translate(offset: Offset(0, dy), child: child),
              );
            },
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 500 + i * 180),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: BallalColors.primary.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 8))],
                ),
                child: Icon(widget.icons[i].$1, color: widget.icons[i].$2, size: 26),
              ),
            ),
          ),
      ]);
    });
  }
}
