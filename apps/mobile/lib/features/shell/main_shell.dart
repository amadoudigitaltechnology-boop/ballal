import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../core/unread.dart';
import '../../widgets/common.dart';

/// Barre de navigation : Accueil · Recherche · (+) · Messages · Profil, avec transitions animées.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  late final AnimationController _fade =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260), value: 1);
  int _last = 0;

  StatefulNavigationShell get shell => widget.shell;

  @override
  void didUpdateWidget(covariant MainShell old) {
    super.didUpdateWidget(old);
    if (shell.currentIndex != _last) {
      _last = shell.currentIndex;
      _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _go(int branch) => shell.goBranch(branch, initialLocation: branch == shell.currentIndex);

  void _plus(BuildContext context) {
    if (!requireAuth(context)) return;
    if (Session.instance.isProMode) {
      context.push('/my-services/edit');
    } else {
      // Une demande se fait toujours vers un professionnel : on part de la recherche.
      _go(1);
      showInfo(context, context.l10n.plusHintClient);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.015), end: Offset.zero)
              .animate(CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic)),
          child: shell,
        ),
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: Listenable.merge([Unread.instance, Session.instance]),
        builder: (context, _) => SafeArea(
          top: false,
          // Barre flottante façon verre : arrondie, légèrement translucide, halo bleu.
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(color: BallalColors.primary.withValues(alpha: 0.16), blurRadius: 28, offset: const Offset(0, 10)),
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white.withValues(alpha: 0.92), const Color(0xFFF1F5FF).withValues(alpha: 0.88)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
                    borderRadius: BorderRadius.circular(30),
                  ),
            child: SizedBox(
              height: 66,
              child: Row(children: [
                _NavItem(icon: Icons.home_rounded, label: l.navHome, selected: shell.currentIndex == 0, onTap: () => _go(0)),
                _NavItem(icon: Icons.search_rounded, label: l.navSearch, selected: shell.currentIndex == 1, onTap: () => _go(1)),
                Expanded(
                  child: Center(
                    child: Semantics(
                      button: true,
                      label: Session.instance.isProMode ? l.addService : l.newRequest,
                      child: _Pressable(
                        onTap: () => _plus(context),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [Color(0xFFFF9A3D), BallalColors.accent, Color(0xFFFF5A00)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            boxShadow: [BoxShadow(color: BallalColors.accent.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                  ),
                ),
                _NavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: l.navMessages,
                  selected: shell.currentIndex == 2,
                  badge: Unread.instance.messages,
                  onTap: () => _go(2),
                ),
                _NavItem(icon: Icons.person_outline_rounded, label: l.navProfile, selected: shell.currentIndex == 3, onTap: () => _go(3)),
              ]),
            ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap, this.badge = 0});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? BallalColors.primary : BallalColors.muted;
    return Expanded(
      child: _Pressable(
        onTap: onTap,
        child: Semantics(
          selected: selected,
          label: label,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(horizontal: selected ? 18 : 10, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? BallalColors.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedScale(
                scale: selected ? 1.12 : 1,
                duration: const Duration(milliseconds: 220),
                child: Badge(
                  isLabelVisible: badge > 0,
                  label: Text(badge > 99 ? '99+' : '$badge'),
                  child: Icon(icon, color: color),
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(fontSize: 11, color: color, fontWeight: selected ? FontWeight.w800 : FontWeight.w500),
              child: Text(label),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Zone tactile qui rétrécit légèrement quand on appuie.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(scale: _down ? 0.88 : 1, duration: const Duration(milliseconds: 110), child: widget.child),
    );
  }
}
