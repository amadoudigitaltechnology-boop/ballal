import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.instance,
      builder: (context, _) => Session.instance.isSignedIn ? const _SignedIn() : const _Guest(),
    );
  }
}

class _Guest extends StatelessWidget {
  const _Guest();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.navProfile)),
      body: ListView(children: [
        const SizedBox(height: 24),
        EmptyState(
          icon: Icons.person_outline_rounded,
          title: l.guestTitle,
          message: l.guestText,
          action: l.login,
          onAction: () => context.push('/login'),
        ),
        ListTile(leading: const Icon(Icons.info_outline), title: Text(l.about), onTap: () => context.push('/about')),
      ]),
    );
  }
}

class _SignedIn extends StatefulWidget {
  const _SignedIn();

  @override
  State<_SignedIn> createState() => _SignedInState();
}

class _SignedInState extends State<_SignedIn> {
  bool _busy = false;

  Future<void> _changeAvatar() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600, imageQuality: 75);
    if (file == null) return;
    setState(() => _busy = true);
    try {
      final path = await AccountRepo.instance.uploadPublicImage('avatars', await file.readAsBytes(), 'avatar');
      await supa.from('profiles').update({'avatar_path': path}).eq('id', currentUserId!);
      await Session.instance.refresh();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _becomePro() async {
    setState(() => _busy = true);
    try {
      await Session.instance.activateRole('professional');
      if (mounted) context.push('/pro-edit');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _becomeClient() async {
    setState(() => _busy = true);
    try {
      await Session.instance.activateRole('client');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switchMode(bool pro) async {
    try {
      await Session.instance.setMode(pro ? 'professional' : 'client');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _logout() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.logoutConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.logout)),
        ],
      ),
    );
    if (ok == true) await Session.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = Session.instance;
    final phone = s.user?.phone;
    Widget item(IconData icon, String label, VoidCallback onTap) => ListTile(
          leading: Icon(icon, color: BallalColors.text),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        );
    return Scaffold(
      appBar: AppBar(title: Text(l.navProfile)),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        const SizedBox(height: 8),
        Center(
          child: Stack(children: [
            Avatar(
              url: s.avatarPath == null ? null : publicUrl('avatars', s.avatarPath!),
              name: s.fullName ?? '',
              size: 92,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: IconButton.filled(
                tooltip: l.changePhoto,
                visualDensity: VisualDensity.compact,
                onPressed: _busy ? null : _changeAvatar,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Center(child: Text(s.fullName ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
        if (s.user?.email != null && s.user!.email!.isNotEmpty)
          Center(child: Text(s.user!.email!, style: const TextStyle(color: BallalColors.muted))),
        if (phone != null && phone.isNotEmpty)
          Center(child: Text('+${phone.replaceAll('+', '')}', style: const TextStyle(color: BallalColors.muted))),
        const SizedBox(height: 16),
        BallalCard(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: s.hasProRole && s.isClient
              ? Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.proMode, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(s.isProMode ? l.proModeOn : l.proModeOff,
                          style: const TextStyle(color: BallalColors.muted, fontSize: 13)),
                    ]),
                  ),
                  Switch(value: s.isProMode, onChanged: _switchMode),
                ])
              : s.hasProRole
                  ? Row(children: [
                      Expanded(child: Text(l.activateClientText)),
                      TextButton(onPressed: _busy ? null : _becomeClient, child: Text(l.activate)),
                    ])
                  : Row(children: [
                      const Icon(Icons.handyman_rounded, color: BallalColors.accent),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l.becomeProText)),
                      TextButton(onPressed: _busy ? null : _becomePro, child: Text(l.becomePro)),
                    ]),
        ),
        const SizedBox(height: 12),
        if (s.hasProRole) ...[
          item(Icons.storefront_outlined, l.myProProfile, () => context.push('/pro-edit')),
          item(Icons.design_services_outlined, l.myServices, () => context.push('/my-services')),
          if (s.isProMode) item(Icons.visibility_outlined, l.seePublicProfile, () => context.push('/pro/${currentUserId!}')),
        ],
        item(Icons.assignment_outlined, s.isProMode ? l.receivedRequests : l.myRequests, () => context.push('/requests')),
        if (s.isClient) item(Icons.favorite_border_rounded, l.myFavorites, () => context.push('/favorites')),
        item(Icons.notifications_none_rounded, l.notifications, () => context.push('/notifications')),
        item(Icons.settings_outlined, l.settings, () => context.push('/settings')),
        item(Icons.info_outline, l.about, () => context.push('/about')),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: BallalColors.danger,
              side: const BorderSide(color: BallalColors.danger),
            ),
            onPressed: _logout,
            child: Text(l.logout),
          ),
        ),
      ]),
    );
  }
}
