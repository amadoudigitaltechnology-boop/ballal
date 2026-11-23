import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatters.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';

/// Faire vérifier son profil : pièce d'identité ou document d'entreprise → badge bleu.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  late Future<List<Map<String, dynamic>>> _future = ProRepo.instance.myVerifications();
  String? _sending;
  int? _fee;
  String? _omNumber;
  final _reference = TextEditingController();

  @override
  void initState() {
    super.initState();
    AppSettingsRepo.instance.publicSettings().then((m) {
      if (!mounted) return;
      final fee = m['verification_fee_gnf'];
      final numbers = m['payment_numbers'];
      setState(() {
        _fee = fee is num ? fee.toInt() : null;
        _omNumber = numbers is Map ? numbers['orange_money'] as String? : null;
      });
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _future = ProRepo.instance.myVerifications());

  Future<void> _whatsapp() async {
    final text = Uri.encodeComponent('Bonjour, je souhaite faire vérifier mon profil BALLAL. Quel est le tarif ?');
    await launchUrl(Uri.parse('https://wa.me/224620657693?text=$text'), mode: LaunchMode.externalApplication);
  }

  Future<void> _send(String type) async {
    final l = context.l10n;
    // Vérification payante : la référence du paiement est demandée avant l'envoi.
    if (_fee != null && _fee! > 0 && _reference.text.trim().length < 4) {
      showInfo(context, l.paymentReferenceRequired);
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l.takePhoto),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l.chooseFromGallery),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(source: source, maxWidth: 2000, imageQuality: 85);
    if (file == null) return;
    setState(() => _sending = type);
    try {
      await ProRepo.instance.submitVerification(
        type,
        await file.readAsBytes(),
        paymentReference: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        paymentMethod: _reference.text.trim().isEmpty ? null : 'orange_money',
        amountGnf: _fee,
      );
      if (mounted) showInfo(context, l.verificationSent);
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.verifyMyProfile)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorState(error: snap.error!, onRetry: _reload);
          if (!snap.hasData) return const LoadingView();
          final docs = snap.data!;
          Map<String, dynamic>? latest(String t) => docs.where((d) => d['doc_type'] == t).firstOrNull;
          return ListView(padding: const EdgeInsets.all(16), children: [
            FadeSlideIn(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(kRadius),
                  gradient: const LinearGradient(colors: [BallalColors.primary, BallalColors.primaryDark]),
                ),
                child: Row(children: [
                  const Icon(Icons.verified_rounded, color: Colors.white, size: 44),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(l.verificationIntro, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.35)),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            if (docs.every((d) => d['status'] != 'approved'))
              FadeSlideIn(
                child: BallalCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: BallalColors.accentSoft, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.payments_outlined, color: BallalColors.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _fee == null ? l.contactUs : l.verificationFee(formatGnf(_fee!)),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    if (_fee == null) ...[
                      Text(l.verificationFeeUnknown, style: const TextStyle(color: BallalColors.muted)),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(onPressed: _whatsapp, icon: const Icon(Icons.chat_rounded, size: 18), label: Text(l.activateViaWhatsapp)),
                    ] else ...[
                      Text(l.verificationFeeHow(_omNumber ?? '620 65 76 93'), style: const TextStyle(color: BallalColors.muted)),
                      const SizedBox(height: 12),
                      FieldLabel(l.paymentReference),
                      TextField(
                        controller: _reference,
                        maxLength: 80,
                        buildCounter: noCounter,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(hintText: l.paymentReferenceHint, prefixIcon: const Icon(Icons.receipt_long_outlined)),
                      ),
                    ],
                  ]),
                ),
              ),
            _DocCard(
              icon: Icons.badge_outlined,
              title: l.docIdentity,
              subtitle: l.docIdentityHint,
              doc: latest('identity'),
              sending: _sending == 'identity',
              onSend: () => _send('identity'),
            ),
            _DocCard(
              icon: Icons.business_center_outlined,
              title: l.docCompany,
              subtitle: l.docCompanyHint,
              doc: latest('company'),
              sending: _sending == 'company',
              onSend: () => _send('company'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.lock_outline_rounded, size: 16, color: BallalColors.muted),
              const SizedBox(width: 6),
              Expanded(child: Text(l.verificationPrivacy, style: const TextStyle(fontSize: 12, color: BallalColors.muted))),
            ]),
          ]);
        },
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.doc,
    required this.sending,
    required this.onSend,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Map<String, dynamic>? doc;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final status = doc?['status'] as String?;
    final (label, color) = switch (status) {
      'approved' => (l.verifApproved, BallalColors.success),
      'pending' => (l.verifPending, BallalColors.warning),
      'rejected' => (l.verifRejected, BallalColors.danger),
      _ => (l.verifNone, BallalColors.muted),
    };
    return FadeSlideIn(
      child: BallalCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: BallalColors.primarySoft, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: BallalColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: BallalColors.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
            const Spacer(),
            if (status != 'pending' && status != 'approved')
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_rounded, size: 18),
                label: Text(status == 'rejected' ? l.sendAgain : l.send),
              ),
          ]),
          if (status == 'rejected' && (doc?['rejection_reason'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(l.rejectionReason(doc!['rejection_reason'] as String),
                style: const TextStyle(fontSize: 12, color: BallalColors.danger)),
          ],
        ]),
      ),
    );
  }
}

/// Options payantes : mise en avant et Premium (activées par l'équipe après paiement).
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  static const _whatsapp = '224620657693';

  Future<void> _contact(BuildContext context, String offer) async {
    final text = Uri.encodeComponent('Bonjour, je souhaite activer l\'option « $offer » pour mon profil BALLAL.');
    final ok = await launchUrl(Uri.parse('https://wa.me/$_whatsapp?text=$text'), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showInfo(context, '+$_whatsapp');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget offer(IconData icon, Color color, String title, String text, List<String> perks) => FadeSlideIn(
          child: BallalCard(
            margin: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
              ]),
              const SizedBox(height: 10),
              Text(text, style: const TextStyle(color: BallalColors.muted)),
              const SizedBox(height: 10),
              for (final p in perks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Icon(Icons.check_circle_rounded, size: 18, color: color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(p)),
                  ]),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: color),
                  onPressed: () => _contact(context, title),
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: Text(l.activateViaWhatsapp),
                ),
              ),
            ]),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l.boostMyProfile)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        offer(Icons.trending_up_rounded, BallalColors.accent, l.sponsored, l.featuredText,
            [l.featuredPerk1, l.featuredPerk2, l.featuredPerk3]),
        offer(Icons.workspace_premium_rounded, const Color(0xFFB8860B), l.premium, l.premiumText,
            [l.premiumPerk1, l.premiumPerk2, l.premiumPerk3]),
        Text(l.paymentNote, style: const TextStyle(fontSize: 12, color: BallalColors.muted)),
      ]),
    );
  }
}
