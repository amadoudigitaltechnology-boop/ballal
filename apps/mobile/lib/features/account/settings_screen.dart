import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';

/// Pages légales publiques (GitHub Pages du dépôt).
const kLegalBaseUrl = 'https://amadoudigitaltechnology-boop.github.io/ballal';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _prefs;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await AccountRepo.instance.preferences();
      setState(() {
        _prefs = p;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  Future<void> _set(String key, dynamic value) async {
    final old = _prefs![key];
    setState(() => _prefs![key] = value);
    try {
      await AccountRepo.instance.updatePreferences({key: value});
      if (key == 'personalization_enabled') await AccountRepo.instance.recordConsent('personalization', value as bool);
    } catch (e) {
      if (mounted) {
        setState(() => _prefs![key] = old);
        showError(context, e);
      }
    }
  }

  Future<void> _editName() async {
    final l = context.l10n;
    final ctrl = TextEditingController(text: Session.instance.fullName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.myName),
        content: TextField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(l.save)),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.length < 2) return;
    try {
      await AccountRepo.instance.updateName(name);
      await Session.instance.refresh();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _myData() {
    final l = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.myData, style: displayStyle(18)),
            const SizedBox(height: 8),
            Text(l.deleteAccountText, style: const TextStyle(color: BallalColors.muted)),
            const SizedBox(height: 12),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: BallalColors.danger),
              onPressed: () {
                Navigator.pop(ctx);
                _deleteAccount();
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(l.deleteAccount),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteAccount),
        content: Text(l.deleteAccountText),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BallalColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AccountRepo.instance.deleteAccount();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = _prefs;
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: _error != null
          ? ErrorState(error: _error!, onRetry: _load)
          : p == null
              ? const LoadingView()
              : ListView(children: [
                  _header(l.myAccount),
                  ListTile(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: Text(l.myName),
                    subtitle: Text(Session.instance.fullName ?? ''),
                    trailing: const Icon(Icons.edit_outlined, size: 20),
                    onTap: _editName,
                  ),
                  ListTile(
                    leading: const Icon(Icons.alternate_email_rounded),
                    title: Text(l.loginEmail),
                    subtitle: Text(Session.instance.user?.email ?? ''),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline_rounded),
                    title: Text(l.changePassword),
                    subtitle: Text(l.changePasswordHint),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/new-password'),
                  ),
                  if (Session.instance.hasProRole) ...[
                    _header(l.proSpace),
                    ListTile(
                      leading: const Icon(Icons.storefront_outlined),
                      title: Text(l.myProProfile),
                      subtitle: Text(l.editProProfileHint),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/pro-edit'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.design_services_outlined),
                      title: Text(l.myServices),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/my-services'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.verified_outlined),
                      title: Text(l.verifyMyProfile),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/verification'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.workspace_premium_outlined),
                      title: Text(l.boostMyProfile),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/premium'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.dashboard_customize_outlined),
                      title: Text(l.proSpace),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/pro-dashboard'),
                    ),
                  ],
                  _header(l.notifications),
                  SwitchListTile(
                    title: Text(l.prefMessages),
                    value: p['notify_messages'] as bool? ?? true,
                    onChanged: (v) => _set('notify_messages', v),
                  ),
                  SwitchListTile(
                    title: Text(l.prefRequests),
                    value: p['notify_requests'] as bool? ?? true,
                    onChanged: (v) => _set('notify_requests', v),
                  ),
                  SwitchListTile(
                    title: Text(l.prefAccount),
                    value: p['notify_account'] as bool? ?? true,
                    onChanged: (v) => _set('notify_account', v),
                  ),
                  SwitchListTile(
                    title: Text(l.prefProduct),
                    value: p['notify_product'] as bool? ?? false,
                    onChanged: (v) => _set('notify_product', v),
                  ),
                  _header(l.privacy),
                  SwitchListTile(
                    title: Text(l.prefPersonalization),
                    subtitle: Text(l.prefPersonalizationHint),
                    value: p['personalization_enabled'] as bool? ?? true,
                    onChanged: (v) => _set('personalization_enabled', v),
                  ),
                  ListTile(
                    title: Text(l.language),
                    subtitle: Text(l.languageFrOnly),
                    leading: const Icon(Icons.translate_rounded),
                  ),
                  ListTile(
                    leading: const Icon(Icons.language_rounded),
                    title: Text(l.language),
                    trailing: const Text('Français', style: TextStyle(color: BallalColors.muted, fontWeight: FontWeight.w600)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.support_agent_rounded),
                    title: Text(l.helpSupport),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => launchUrl(Uri.parse('https://wa.me/224620657693'), mode: LaunchMode.externalApplication),
                  ),
                  _header(l.legal),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: Text(l.privacyPolicy),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => launchUrl(Uri.parse('$kLegalBaseUrl/confidentialite.html'), mode: LaunchMode.externalApplication),
                  ),
                  ListTile(
                    leading: const Icon(Icons.gavel_outlined),
                    title: Text(l.termsOfUse),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => launchUrl(Uri.parse('$kLegalBaseUrl/conditions.html'), mode: LaunchMode.externalApplication),
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(l.about),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/about'),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BallalColors.danger,
                        side: const BorderSide(color: BallalColors.danger),
                        minimumSize: const Size(64, 52),
                      ),
                      onPressed: () => Session.instance.signOut(),
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(l.logout),
                    ),
                  ),
                  // Exigence Google Play : la suppression du compte doit rester possible dans l'application.
                  // Elle est rangée discrètement dans « Mes données ».
                  Center(
                    child: TextButton(
                      onPressed: _myData,
                      child: Text(l.myData, style: const TextStyle(color: BallalColors.muted, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ]),
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(t.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: BallalColors.muted, letterSpacing: 0.6)),
      );
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget block(String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            Text(text, style: const TextStyle(height: 1.45)),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l.about)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Center(child: BallalLogo(size: 40)),
        const SizedBox(height: 8),
        Center(child: Text(l.aboutTagline, textAlign: TextAlign.center, style: const TextStyle(color: BallalColors.muted))),
        const SizedBox(height: 24),
        block(l.howItWorks, l.howItWorksText),
        block(l.freeTitle, l.freeText),
        block(l.privacy, l.privacyText),
        block(l.termsTitle, l.termsText),
        block(l.contactTitle, l.contactText),
        const SizedBox(height: 8),
        Center(child: Text('BALLAL · Amadou Technology · v0.1.0', style: const TextStyle(color: BallalColors.muted, fontSize: 12))),
        if (Navigator.of(context).canPop()) ...[
          const SizedBox(height: 16),
          OutlinedButton(onPressed: () => context.pop(), child: Text(l.back)),
        ],
      ]),
    );
  }
}
