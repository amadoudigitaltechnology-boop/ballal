import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../../core/formatters.dart';
import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../../widgets/celebration.dart';
import '../../widgets/common.dart';
import '../../widgets/skyline.dart';

/// Connexion (maquette) : logo, « Bienvenue ! », e-mail + mot de passe, Google.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _google = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // L'application se souvient du dernier e-mail utilisé.
    SharedPreferences.getInstance().then((p) {
      final last = p.getString('last_email');
      if (last != null && mounted && _email.text.isEmpty) setState(() => _email.text = last);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final email = normalizeEmail(_email.text);
    if (email == null) {
      showInfo(context, l.emailInvalid);
      return;
    }
    if (_password.text.isEmpty) {
      showInfo(context, l.passwordTooShort);
      return;
    }
    setState(() => _loading = true);
    try {
      await AccountRepo.instance.signInWithPassword(email, _password.text);
      TextInput.finishAutofillContext();
      await rememberEmail(email);
      // La suite (profil à compléter ou accueil) est gérée par le routeur.
    } on AuthException catch (e) {
      if (!mounted) return;
      final m = e.message.toLowerCase();
      if (m.contains('not confirmed')) {
        await AccountRepo.instance.resendSignupCode(email);
        if (mounted) context.push('/otp', extra: {'email': email, 'mode': 'signup'});
      } else if (m.contains('invalid')) {
        showInfo(context, l.wrongPassword);
      } else {
        showError(context, e);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _withGoogle() async {
    setState(() => _google = true);
    await signInWithGoogle(context);
    if (mounted) setState(() => _google = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [
        const Positioned(top: 0, right: 0, child: CornerSwoosh(size: 150)),
        SafeArea(
          child: AutofillGroup(
            child: ListView(padding: const EdgeInsets.fromLTRB(24, 48, 24, 24), children: [
              const FadeSlideIn(child: Center(child: BallalLogo(size: 46))),
              const SizedBox(height: 28),
              FadeSlideIn(
                index: 1,
                child: Column(children: [
                  Text(l.welcomeTitle, textAlign: TextAlign.center, style: displayStyle(28, color: BallalColors.text)),
                  const SizedBox(height: 6),
                  Text(l.loginSubtitle, textAlign: TextAlign.center, style: const TextStyle(color: BallalColors.muted, fontSize: 15)),
                ]),
              ),
              const SizedBox(height: 28),
              FadeSlideIn(
                index: 2,
                child: TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email, AutofillHints.username],
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.alternate_email_rounded), hintText: l.emailLabel),
                ),
              ),
              const SizedBox(height: 14),
              FadeSlideIn(
                index: 3,
                child: TextField(
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    hintText: l.passwordLabel,
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password', extra: normalizeEmail(_email.text)),
                  child: Text(l.forgotPassword, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 6),
              FadeSlideIn(
                index: 4,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(l.tabLogin),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ]),
                ),
              ),
              const OrDivider(),
              GoogleButton(loading: _google, onPressed: _withGoogle),
              const SizedBox(height: 22),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(l.noAccountYet, style: const TextStyle(color: BallalColors.muted)),
                TextButton(
                  onPressed: () => context.go('/signup'),
                  child: Text(l.tabSignup, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ]),
              TextButton(
                onPressed: () => context.push('/about'),
                child: Text(l.about, style: const TextStyle(color: BallalColors.muted, fontSize: 12)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Créer un compte (maquette) : nom complet, e-mail, mot de passe, confirmation, Google.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _google = false;
  bool _obscure = true;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final email = normalizeEmail(_email.text);
    if (_name.text.trim().length < 2) {
      showInfo(context, l.nameRequired);
      return;
    }
    if (email == null) {
      showInfo(context, l.emailInvalid);
      return;
    }
    if (_password.text.length < 8) {
      showInfo(context, l.passwordTooShort);
      return;
    }
    if (_password.text != _confirm.text) {
      showInfo(context, l.passwordsDontMatch);
      return;
    }
    setState(() => _loading = true);
    try {
      final needsCode = await AccountRepo.instance.signUpWithPassword(email, _password.text, fullName: _name.text.trim());
      TextInput.finishAutofillContext();
      await rememberEmail(email);
      if (needsCode && mounted) context.push('/otp', extra: {'email': email, 'mode': 'signup'});
    } on AuthException catch (e) {
      if (!mounted) return;
      final m = e.message.toLowerCase();
      if (m.contains('already')) {
        showInfo(context, l.emailAlreadyUsed);
        context.go('/login');
      } else if (m.contains('password')) {
        showInfo(context, l.passwordTooShort);
      } else {
        showError(context, e);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _withGoogle() async {
    setState(() => _google = true);
    await signInWithGoogle(context);
    if (mounted) setState(() => _google = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget field(int i, TextEditingController c, IconData icon, String hint,
            {bool password = false, TextInputType? type, Iterable<String>? hints, TextInputAction action = TextInputAction.next}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FadeSlideIn(
            index: i,
            child: TextField(
              controller: c,
              obscureText: password && _obscure,
              keyboardType: type,
              autofillHints: hints,
              autocorrect: !password && type != TextInputType.emailAddress,
              textCapitalization: type == TextInputType.name ? TextCapitalization.words : TextCapitalization.none,
              textInputAction: action,
              onSubmitted: action == TextInputAction.done ? (_) => _submit() : null,
              decoration: InputDecoration(
                prefixIcon: Icon(icon),
                hintText: hint,
                suffixIcon: password
                    ? IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      )
                    : null,
              ),
            ),
          ),
        );
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [
        const Positioned(top: 0, right: 0, child: CornerSwoosh(size: 130)),
        SafeArea(
          child: AutofillGroup(
            child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
                ),
              ),
              const FadeSlideIn(child: Center(child: BallalLogo(size: 42))),
              const SizedBox(height: 22),
              Text(l.tabSignup, textAlign: TextAlign.center, style: displayStyle(26, color: BallalColors.text)),
              const SizedBox(height: 6),
              Text(l.joinCommunity, textAlign: TextAlign.center, style: const TextStyle(color: BallalColors.muted, fontSize: 15)),
              const SizedBox(height: 24),
              field(1, _name, Icons.person_outline_rounded, l.fullName, type: TextInputType.name, hints: const [AutofillHints.name]),
              field(2, _email, Icons.mail_outline_rounded, l.emailLabel,
                  type: TextInputType.emailAddress, hints: const [AutofillHints.email, AutofillHints.username]),
              field(3, _password, Icons.lock_outline_rounded, '${l.passwordLabel} (${l.passwordHint})',
                  password: true, hints: const [AutofillHints.newPassword]),
              field(4, _confirm, Icons.lock_reset_rounded, l.confirmPassword,
                  password: true, hints: const [AutofillHints.newPassword], action: TextInputAction.done),
              const SizedBox(height: 6),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(l.tabSignup),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 20),
                      ]),
              ),
              const OrDivider(),
              GoogleButton(loading: _google, onPressed: _withGoogle),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(l.alreadyAccount, style: const TextStyle(color: BallalColors.muted)),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(l.tabLogin, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ]),
              Text(l.termsNotice, textAlign: TextAlign.center, style: const TextStyle(color: BallalColors.muted, fontSize: 11)),
            ]),
          ),
        ),
      ]),
    );
  }
}

Future<void> rememberEmail(String email) async {
  final p = await SharedPreferences.getInstance();
  await p.setString('last_email', email);
}

/// « Continuer avec Google » dans un onglet intégré (l'application Gmail n'intercepte pas la page).
Future<void> signInWithGoogle(BuildContext context) async {
  final l = context.l10n;
  try {
    await supa.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.amadoutechnology.ballal://login-callback',
      authScreenLaunchMode: LaunchMode.inAppBrowserView,
    );
  } catch (e) {
    if (!context.mounted) return;
    final msg = e.toString().toLowerCase();
    showInfo(context, msg.contains('provider') || msg.contains('not enabled') ? l.googleNotReady : l.genericError);
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(context.l10n.or, style: const TextStyle(color: BallalColors.muted)),
          ),
          const Expanded(child: Divider()),
        ]),
      );
}

class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.loading, required this.onPressed});
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 54), backgroundColor: Colors.white),
        child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                const _GoogleG(),
                const SizedBox(width: 10),
                Text(context.l10n.continueWithGoogle,
                    style: const TextStyle(color: BallalColors.text, fontWeight: FontWeight.w700)),
              ]),
      );
}

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.email, this.mode = 'login'});
  final String email;
  /// 'login' (code de connexion), 'signup' (confirmation d'inscription), 'recovery' (mot de passe oublié).
  final String mode;

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
      await AccountRepo.instance.verifyEmailOtp(widget.email, code, mode: widget.mode);
      // Mot de passe oublié : on choisit tout de suite le nouveau mot de passe.
      if (widget.mode == 'recovery' && mounted) context.go('/new-password');
      // Sinon la redirection (profil à compléter ou accueil) est gérée par le routeur.
    } catch (e) {
      _code.clear();
      if (!mounted) return;
      final m = e.toString().toLowerCase();
      if (m.contains('user not found')) {
        showInfo(context, context.l10n.noAccountForEmail);
      } else if (m.contains('expired') || m.contains('invalid')) {
        showInfo(context, context.l10n.codeInvalidOrExpired);
      } else {
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      switch (widget.mode) {
        case 'signup':
          await AccountRepo.instance.resendSignupCode(widget.email);
        case 'recovery':
          await AccountRepo.instance.sendPasswordReset(widget.email);
        default:
          await AccountRepo.instance.sendEmailOtp(widget.email);
      }
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
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: BallalColors.primarySoft, shape: BoxShape.circle),
            child: const Icon(Icons.mark_email_read_outlined, color: BallalColors.primary, size: 36),
          ),
          const SizedBox(height: 18),
          Text(l.otpTitle, style: displayStyle(26, color: BallalColors.primaryDark)),
          const SizedBox(height: 8),
          Text(l.otpSubtitle6(widget.email), style: const TextStyle(color: BallalColors.muted, fontSize: 15)),
          const SizedBox(height: 28),
          _CodeBoxes(controller: _code, onChanged: () {
            setState(() {});
            if (_code.text.length == 6) _verify();
          }),
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

/// Six cases pour le code reçu par e-mail (saisie, collage et remplissage automatique).
class _CodeBoxes extends StatefulWidget {
  const _CodeBoxes({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  State<_CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<_CodeBoxes> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(alignment: Alignment.center, children: [
        // Champ invisible qui reçoit réellement la saisie.
        Opacity(
          opacity: 0,
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            maxLength: 6,
            showCursor: false,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            onChanged: (_) => widget.onChanged(),
            decoration: const InputDecoration(counterText: ''),
          ),
        ),
        IgnorePointer(
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (var i = 0; i < 6; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i < text.length ? BallalColors.primarySoft : BallalColors.field,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: i == text.length ? BallalColors.primary : Colors.transparent,
                    width: 1.6,
                  ),
                ),
                child: AnimatedScale(
                  scale: i < text.length ? 1 : 0.4,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: Text(i < text.length ? text[i] : '',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: BallalColors.primaryDark)),
                ),
                  ),
                ),
              ),
          ]),
        ),
      ]),
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
  final _name = TextEditingController(
      text: Session.instance.fullName ?? (supa.auth.currentUser?.userMetadata?['full_name'] as String?) ?? '');
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
      if (mounted) await showAccountCreated(context, _name.text.trim().split(' ').first);
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
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            boxShadow: selected
                ? [BoxShadow(color: BallalColors.primary.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 8))]
                : null,
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
          Text(l.setupTitle, style: displayStyle(28, color: BallalColors.primaryDark)),
          const SizedBox(height: 6),
          Text(l.setupSubtitle, style: const TextStyle(color: BallalColors.muted)),
          const SizedBox(height: 24),
          FieldLabel(l.fullName),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Ex. : Mamadou Diallo', prefixIcon: Icon(Icons.person_outline)),
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


/// « G » multicolore dessiné (pas d'image de marque embarquée).
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) => SizedBox(width: 20, height: 20, child: CustomPaint(painter: _GPainter()));
}

class _GPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.2;
    final r = rect.deflate(stroke / 2);
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(r, -0.75, -1.6, false, p(const Color(0xFFEA4335)));
    canvas.drawArc(r, -2.35, -1.55, false, p(const Color(0xFFFBBC05)));
    canvas.drawArc(r, 2.38, -1.6, false, p(const Color(0xFF34A853)));
    canvas.drawArc(r, 0.78, -0.78, false, p(const Color(0xFF4285F4)));
    canvas.drawLine(Offset(size.width / 2, size.height / 2), Offset(size.width - stroke / 2, size.height / 2),
        Paint()
          ..color = const Color(0xFF4285F4)
          ..strokeWidth = stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


/// Mot de passe oublié : on envoie un code à 6 chiffres par e-mail.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_email.text.isEmpty) {
      final initial = GoRouterState.of(context).extra;
      if (initial is String) _email.text = initial;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = context.l10n;
    final email = normalizeEmail(_email.text);
    if (email == null) {
      showInfo(context, l.emailInvalid);
      return;
    }
    setState(() => _loading = true);
    try {
      await AccountRepo.instance.sendPasswordReset(email);
      if (mounted) context.push('/otp', extra: {'email': email, 'mode': 'recovery'});
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
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: BallalColors.accentSoft, shape: BoxShape.circle),
            child: const Icon(Icons.key_rounded, color: BallalColors.accent, size: 34),
          ),
          const SizedBox(height: 18),
          Text(l.forgotTitle, style: displayStyle(26, color: BallalColors.primaryDark)),
          const SizedBox(height: 8),
          Text(l.forgotText, style: const TextStyle(color: BallalColors.muted, fontSize: 15)),
          const SizedBox(height: 24),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.alternate_email_rounded), hintText: l.emailLabel),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _send,
            child: _loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(l.sendCode),
          ),
        ]),
      ),
    );
  }
}

/// Choisir (ou changer) son mot de passe — après « Mot de passe oublié » ou depuis les Paramètres.
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (_password.text.length < 8) {
      showInfo(context, l.passwordTooShort);
      return;
    }
    if (_password.text != _confirm.text) {
      showInfo(context, l.passwordsDontMatch);
      return;
    }
    setState(() => _loading = true);
    try {
      await AccountRepo.instance.updatePassword(_password.text);
      TextInput.finishAutofillContext();
      if (!mounted) return;
      showInfo(context, l.passwordSaved);
      if (Navigator.of(context).canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
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
        child: AutofillGroup(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: BallalColors.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.lock_reset_rounded, color: BallalColors.primary, size: 34),
            ),
            const SizedBox(height: 18),
            Text(l.newPasswordTitle, style: displayStyle(26, color: BallalColors.primaryDark)),
            const SizedBox(height: 8),
            Text(l.newPasswordText, style: const TextStyle(color: BallalColors.muted, fontSize: 15)),
            const SizedBox(height: 24),
            TextField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                hintText: '${l.passwordLabel} (${l.passwordHint})',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.lock_reset_rounded), hintText: l.confirmPassword),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(l.save),
            ),
          ]),
        ),
      ),
    );
  }
}
