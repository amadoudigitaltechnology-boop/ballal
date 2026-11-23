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
import '../onboarding/onboarding_screen.dart';

/// Connexion par code reçu par e-mail — gratuit, sans mot de passe.
/// (Le téléphone / WhatsApp pourra être réactivé plus tard via AccountRepo.sendOtp.)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _signup = false;
  bool _obscure = true;
  String? _error;

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
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _remember(String email) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('last_email', email);
  }

  /// Connexion ou création de compte avec e-mail + mot de passe.
  Future<void> _passwordSubmit() async {
    final l = context.l10n;
    final email = normalizeEmail(_email.text);
    if (email == null) {
      setState(() => _error = l.emailInvalid);
      return;
    }
    if (_password.text.length < 8) {
      showInfo(context, l.passwordTooShort);
      return;
    }
    if (_signup && _password.text != _confirm.text) {
      showInfo(context, l.passwordsDontMatch);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_signup) {
        final needsCode = await AccountRepo.instance.signUpWithPassword(email, _password.text);
        TextInput.finishAutofillContext(); // propose d'enregistrer l'identifiant dans le téléphone
        await _remember(email);
        if (needsCode && mounted) context.push('/otp', extra: {'email': email, 'mode': 'signup'});
      } else {
        await AccountRepo.instance.signInWithPassword(email, _password.text);
        TextInput.finishAutofillContext();
        await _remember(email);
      }
      // La suite (profil à compléter ou accueil) est gérée par le routeur.
    } on AuthException catch (e) {
      if (!mounted) return;
      final m = e.message.toLowerCase();
      if (m.contains('already_registered') || m.contains('already registered')) {
        showInfo(context, l.emailAlreadyUsed);
        setState(() => _signup = false);
      } else if (m.contains('invalid login') || m.contains('invalid credentials')) {
        showInfo(context, l.wrongPassword);
      } else if (m.contains('not confirmed')) {
        await AccountRepo.instance.resendSignupCode(email);
        if (mounted) context.push('/otp', extra: {'email': email, 'mode': 'signup'});
      } else {
        showError(context, e);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _google = false;

  /// « Continuer avec Google » : connexion en un clic avec le compte Gmail.
  Future<void> _signInWithGoogle() async {
    final l = context.l10n;
    setState(() => _google = true);
    try {
      await supa.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.amadoutechnology.ballal://login-callback',
        // Onglet de navigateur intégré : évite que l'application Gmail intercepte la page Google.
        authScreenLaunchMode: LaunchMode.inAppBrowserView,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      showInfo(context, msg.contains('provider') || msg.contains('not enabled') ? l.googleNotReady : l.genericError);
    } finally {
      if (mounted) setState(() => _google = false);
    }
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
      await _remember(email);
      if (mounted) context.push('/otp', extra: {'email': email, 'mode': 'login'});
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(padding: EdgeInsets.zero, children: [
        // Photo d'accueil sur la vague bleue, logo en haut à droite (maquette).
        BallalWave(
          height: (h * 0.42).clamp(280.0, 380.0),
          child: Stack(children: [
            Positioned(
              left: 24,
              bottom: 34,
              top: MediaQuery.of(context).padding.top + 20,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(offset: Offset(-30 * (1 - v), 0), child: child),
                ),
                child: AspectRatio(
                  aspectRatio: 0.92,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [BoxShadow(color: BallalColors.primary.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 12))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset('assets/people/woman_phone.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: MediaQuery.of(context).padding.top + 28,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: const BallalLogo(size: 22),
              ),
            ),
          ]),
        ),
        FadeSlideIn(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(l.welcomeTitle, style: displayStyle(30, color: BallalColors.primaryDark)),
              const SizedBox(height: 4),
              Text(_signup ? l.signupSubtitle : l.loginSubtitle, style: const TextStyle(color: BallalColors.muted, fontSize: 15)),
              const SizedBox(height: 18),
              // Bascule Se connecter / Créer un compte (pastille animée).
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: BallalColors.field, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  for (final signup in [false, true])
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _signup = signup),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: _signup == signup ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _signup == signup
                                ? [BoxShadow(color: BallalColors.primary.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 3))]
                                : null,
                          ),
                          child: Text(
                            signup ? l.tabSignup : l.tabLogin,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _signup == signup ? BallalColors.primary : BallalColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 18),
              AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email, AutofillHints.username],
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                      hintText: l.emailLabel,
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    autofillHints: [_signup ? AutofillHints.newPassword : AutofillHints.password],
                    textInputAction: _signup ? TextInputAction.next : TextInputAction.done,
                    onSubmitted: (_) => _signup ? null : _passwordSubmit(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      hintText: _signup ? '${l.passwordLabel} (${l.passwordHint})' : l.passwordLabel,
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    child: !_signup
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: TextField(
                              controller: _confirm,
                              obscureText: _obscure,
                              autofillHints: const [AutofillHints.newPassword],
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _passwordSubmit(),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.lock_reset_rounded),
                                hintText: l.confirmPassword,
                              ),
                            ),
                          ),
                  ),
                ]),
              ),
              if (!_signup)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password', extra: normalizeEmail(_email.text)),
                    child: Text(l.forgotPassword),
                  ),
                )
              else
                const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _passwordSubmit,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Row(key: ValueKey(_signup), mainAxisSize: MainAxisSize.min, children: [
                          Text(_signup ? l.tabSignup : l.tabLogin),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ]),
                ),
              ),
              if (!_signup)
                TextButton(onPressed: _loading ? null : _submit, child: Text(l.loginWithCode)),
              const SizedBox(height: 16),
              Row(children: [
                const Expanded(child: Divider()),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(l.or, style: const TextStyle(color: BallalColors.muted))),
                const Expanded(child: Divider()),
              ]),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _google ? null : _signInWithGoogle,
                style: OutlinedButton.styleFrom(minimumSize: const Size(64, 54), backgroundColor: Colors.white),
                child: _google
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        const _GoogleG(),
                        const SizedBox(width: 10),
                        Text(l.continueWithGoogle, style: const TextStyle(color: BallalColors.text, fontWeight: FontWeight.w700)),
                      ]),
              ),
              const SizedBox(height: 18),
              Text(l.termsNotice, textAlign: TextAlign.center, style: const TextStyle(color: BallalColors.muted, fontSize: 12)),
              TextButton(onPressed: () => context.push('/about'), child: Text(l.about)),
            ]),
          ),
        ),
      ]),
    );
  }
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
