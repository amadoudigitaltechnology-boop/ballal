import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';

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
                  _header(l.account),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_outlined, color: BallalColors.danger),
                    title: Text(l.deleteAccount, style: const TextStyle(color: BallalColors.danger)),
                    onTap: _deleteAccount,
                  ),
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
