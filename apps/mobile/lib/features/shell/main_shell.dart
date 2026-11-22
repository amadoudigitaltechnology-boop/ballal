import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../core/unread.dart';
import '../../widgets/common.dart';

/// Barre de navigation : Accueil · Recherche · (+) · Messages · Profil.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

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
      body: shell,
      bottomNavigationBar: ListenableBuilder(
        listenable: Listenable.merge([Unread.instance, Session.instance]),
        builder: (context, _) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(children: [
                _NavItem(icon: Icons.home_rounded, label: l.navHome, selected: shell.currentIndex == 0, onTap: () => _go(0)),
                _NavItem(icon: Icons.search_rounded, label: l.navSearch, selected: shell.currentIndex == 1, onTap: () => _go(1)),
                Expanded(
                  child: Center(
                    child: Semantics(
                      button: true,
                      label: Session.instance.isProMode ? l.addService : l.newRequest,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _plus(context),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [BallalColors.primary, BallalColors.primaryDark]),
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
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          selected: selected,
          label: label,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text(badge > 99 ? '99+' : '$badge'),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}
