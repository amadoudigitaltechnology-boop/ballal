import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';

/// Connexion par code reçu par e-mail — gratuit, sans mot de passe.
/// (Le téléphone / WhatsApp pourra être réactivé plus tard via AccountRepo.sendOtp.)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final email = normalizeEmail(_email.text);
    if (email == null) {
      setState(() => _error = l.emailInvalid);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AccountRepo.instance.sendEmailOtp(email);
      if (mounted) context.push('/otp', extra: email);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const BallalLogo(size: 32),
          const SizedBox(height: 28),
          Text(l.welcomeTitle, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(l.loginSubtitle, style: const TextStyle(color: BallalColors.muted, fontSize: 15)),
          const SizedBox(height: 28),
          Text(l.emailLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.mail_outline),
              hintText: 'nom@exemple.com',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 8),
          Text(l.otpInfo, style: const TextStyle(color: BallalColors.muted, fontSize: 13)),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(l.receiveCode),
          ),
          const SizedBox(height: 16),
          Text(l.termsNotice, textAlign: TextAlign.center, style: const TextStyle(color: BallalColors.muted, fontSize: 12)),
        ]),
      ),
    );
  }
}

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.email});
  final String email;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  int _cooldown = 60;
  int _attempts = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) t.cancel();
      if (mounted) setState(() => _cooldown--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 6 || _loading) return;
    if (_attempts >= 5) {
      showInfo(context, context.l10n.otpTooManyAttempts);
      return;
    }
    setState(() => _loading = true);
    _attempts++;
    try {
      await AccountRepo.instance.verifyEmailOtp(widget.email, code);
      // La redirection (profil à compléter ou accueil) est gérée par le routeur.
    } catch (e) {
      _code.clear();
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      await AccountRepo.instance.sendEmailOtp(widget.email);
      _attempts = 0;
      _startCooldown();
      if (mounted) showInfo(context, context.l10n.codeResent);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Text(l.otpTitle, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(l.otpSubtitleEmail(widget.email), style: const TextStyle(color: BallalColors.muted, fontSize: 15)),
          const SizedBox(height: 28),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            maxLength: 8,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.w700),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _verify(),
            decoration: const InputDecoration(counterText: '', hintText: '••••••'),
          ),
          const SizedBox(height: 8),
          Text(l.checkSpam, textAlign: TextAlign.center, style: const TextStyle(color: BallalColors.muted, fontSize: 12)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading || _code.text.trim().length < 6 ? null : _verify,
            child: _loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(l.verify),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _cooldown > 0 ? null : _resend,
              child: Text(_cooldown > 0 ? l.resendIn(_cooldown.toString()) : l.resendCode),
            ),
          ),
          TextButton(onPressed: () => context.pop(), child: Text(l.changeEmail)),
        ]),
      ),
    );
  }
}

/// Après la première connexion : nom, choix du profil, acceptation des conditions.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _name = TextEditingController(text: Session.instance.fullName ?? '');
  String? _role;
  bool _accepted = false;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().length >= 2 && _role != null && _accepted;

  Future<void> _submit() async {
    if (!_valid) return;
    setState(() => _loading = true);
    try {
      await AccountRepo.instance.completeSetup(fullName: _name.text, role: _role!);
      await Session.instance.refresh();
      if (mounted && _role == 'professional') context.go('/pro-edit');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _roleCard(String role, IconData icon, String title, String subtitle) {
    final selected = _role == role;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: () => setState(() => _role = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? BallalColors.primarySoft : Colors.white,
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: selected ? BallalColors.primary : BallalColors.border, width: selected ? 2 : 1),
          ),
          child: Row(children: [
            Icon(icon, size: 32, color: BallalColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text(subtitle, style: const TextStyle(color: BallalColors.muted, fontSize: 13)),
              ]),
            ),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? BallalColors.primary : BallalColors.muted),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Text(l.setupTitle, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(l.setupSubtitle, style: const TextStyle(color: BallalColors.muted)),
          const SizedBox(height: 24),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l.fullName, prefixIcon: const Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 24),
          Text(l.chooseProfile, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          _roleCard('client', Icons.search_rounded, l.roleClientTitle, l.roleClientSubtitle),
          _roleCard('professional', Icons.handyman_rounded, l.roleProTitle, l.roleProSubtitle),
          Text(l.roleSwitchLater, style: const TextStyle(color: BallalColors.muted, fontSize: 12)),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _accepted,
            onChanged: (v) => setState(() => _accepted = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(l.acceptTerms, style: const TextStyle(fontSize: 14)),
            subtitle: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
              onPressed: () => context.push('/about'),
              child: Text(l.readTerms),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _valid && !_loading ? _submit : null,
            child: _loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(l.continueLabel),
          ),
          TextButton(onPressed: () => Session.instance.signOut(), child: Text(l.logout)),
        ]),
      ),
    );
  }
}

class SuspendedScreen extends StatelessWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: EmptyState(
        icon: Icons.block_rounded,
        title: l.suspendedTitle,
        message: l.suspendedText,
        action: l.logout,
        onAction: () => Session.instance.signOut(),
      ),
    );
  }
}
