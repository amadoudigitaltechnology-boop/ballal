import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: BallalLogo(size: 44)),
    );
  }
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

  Future<void> _finish(String target) async {
    await Session.instance.markOnboardingSeen();
    if (mounted) context.go(target);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pages = [
      (Icons.search_rounded, l.onb1Title, l.onb1Text),
      (Icons.chat_rounded, l.onb2Title, l.onb2Text),
      (Icons.verified_user_rounded, l.onb3Title, l.onb3Text),
    ];
    final last = _page == pages.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
            child: Row(children: [
              const BallalLogo(),
              const Spacer(),
              if (!last) TextButton(onPressed: () => _finish('/home'), child: Text(l.skip)),
            ]),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final (icon, title, text) = pages[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 220,
                      height: 220,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [BallalColors.primarySoft, BallalColors.accentSoft],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(icon, size: 96, color: BallalColors.primary),
                    ),
                    const SizedBox(height: 40),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: BallalColors.primaryDark, height: 1.2)),
                    const SizedBox(height: 12),
                    Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: BallalColors.muted, height: 1.4)),
                  ]),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pages.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
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
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: FilledButton(
              onPressed: last
                  ? () => _finish('/home')
                  : () => _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(last ? l.start : l.next),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 20),
              ]),
            ),
          ),
          TextButton(onPressed: () => _finish('/login'), child: Text(l.haveAccountLogin)),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
