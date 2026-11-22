import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/formatters.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';

/// Demande de service en 3 étapes : Service · Détails · Confirmation.
class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key, required this.proId, required this.proName, this.service});
  final String proId;
  final String proName;
  final ProService? service;

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  int _step = 0;
  late final _title = TextEditingController(text: widget.service?.title ?? '');
  final _description = TextEditingController();
  final _addressHint = TextEditingController();
  final _budget = TextEditingController();
  Place? _place;
  String? _placeLabel;
  DateTime? _date;
  final List<Uint8List> _photos = [];
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _addressHint.dispose();
    _budget.dispose();
    super.dispose();
  }

  bool get _step0Valid => _title.text.trim().length >= 2;
  bool get _step1Valid => _description.text.trim().length >= 5;

  Future<void> _pickPlace() async {
    final p = await pickPlace(context);
    if (p == null) return;
    final label = await CatalogRepo.instance.label(p);
    setState(() {
      _place = p;
      _placeLabel = label;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= 3) return;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 72);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) showInfo(context, context.l10n.photoTooLarge);
      return;
    }
    setState(() => _photos.add(bytes));
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final budget = int.tryParse(_budget.text.replaceAll(RegExp(r'[^0-9]'), ''));
      final id = await RequestRepo.instance.create(
        professionalId: widget.proId,
        serviceId: widget.service?.id,
        categoryId: widget.service?.categoryId,
        title: _title.text.trim(),
        description: _description.text.trim(),
        locationId: _place?.id,
        addressHint: _addressHint.text.trim().isEmpty ? null : _addressHint.text.trim(),
        desiredDate: _date,
        budgetMax: budget,
        photos: _photos,
      );
      if (mounted) context.pushReplacement('/request/sent', extra: id);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _next() {
    if (_step == 0 && !_step0Valid) return;
    if (_step == 1 && !_step1Valid) return;
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _send();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final steps = [l.stepService, l.stepDetails, l.stepConfirm];
    final canNext = switch (_step) { 0 => _step0Valid, 1 => _step1Valid, _ => !_sending };
    return Scaffold(
      appBar: AppBar(
        title: Text(l.serviceRequest),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _step == 0 ? context.pop() : setState(() => _step--),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(children: [
            for (var i = 0; i < steps.length; i++) ...[
              Column(children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: i <= _step ? BallalColors.primary : Colors.white,
                  foregroundColor: i <= _step ? Colors.white : BallalColors.muted,
                  child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 4),
                Text(steps[i], style: TextStyle(fontSize: 12, color: i == _step ? BallalColors.primary : BallalColors.muted)),
              ]),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 18),
                    color: i < _step ? BallalColors.primary : BallalColors.border,
                  ),
                ),
            ],
          ]),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(key: ValueKey(_step), child: _buildStep(context)),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: FilledButton(
              onPressed: canNext ? _next : null,
              child: _sending
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_step == 2 ? l.sendRequest : l.next),
                      const SizedBox(width: 8),
                      Icon(_step == 2 ? Icons.send_rounded : Icons.arrow_forward_rounded, size: 20),
                    ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildStep(BuildContext context) {
    final l = context.l10n;
    switch (_step) {
      case 0:
        return ListView(padding: const EdgeInsets.all(20), children: [
          Text(l.requestTo(widget.proName), style: const TextStyle(color: BallalColors.muted)),
          const SizedBox(height: 16),
          Text(l.whatDoYouNeed, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            maxLength: 120,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: l.requestTitleHint),
          ),
        ]);
      case 1:
        return ListView(padding: const EdgeInsets.all(20), children: [
          Text(l.description, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _description,
            maxLines: 5,
            maxLength: 2000,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: l.describeNeed),
          ),
          const SizedBox(height: 12),
          Text(l.location, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading: const Icon(Icons.place_outlined, color: BallalColors.primary),
            title: Text(_placeLabel ?? l.chooseZone),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickPlace,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _addressHint,
            maxLength: 200,
            decoration: InputDecoration(hintText: l.addressHint, helperText: l.addressHintPrivate),
          ),
          const SizedBox(height: 8),
          Text(l.desiredDate, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading: const Icon(Icons.event_outlined, color: BallalColors.primary),
            title: Text(_date == null ? l.optional : formatDate(_date!)),
            onTap: _pickDate,
          ),
          const SizedBox(height: 16),
          Text(l.budgetOptional, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _budget,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(suffixText: 'GNF'),
          ),
          const SizedBox(height: 16),
          Text(l.photosOptional, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < _photos.length; i++)
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_photos[i], width: 84, height: 84, fit: BoxFit.cover),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    tooltip: l.remove,
                    style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _photos.removeAt(i)),
                  ),
                ),
              ]),
            if (_photos.length < 3)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _addPhoto,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BallalColors.border),
                  ),
                  child: const Icon(Icons.add_a_photo_outlined, color: BallalColors.primary),
                ),
              ),
          ]),
        ]);
      default:
        final budget = int.tryParse(_budget.text);
        return ListView(padding: const EdgeInsets.all(20), children: [
          Text(l.checkBeforeSend, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          _summary(l.professional, widget.proName),
          _summary(l.need, _title.text.trim()),
          _summary(l.description, _description.text.trim()),
          if (_placeLabel != null) _summary(l.location, _placeLabel!),
          if (_date != null) _summary(l.desiredDate, formatDate(_date!)),
          if (budget != null) _summary(l.budget, formatGnf(budget)),
          if (_photos.isNotEmpty) _summary(l.photos, '${_photos.length}'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: BallalColors.primarySoft, borderRadius: BorderRadius.circular(12)),
            child: Text(l.noPaymentNotice, style: const TextStyle(fontSize: 13)),
          ),
        ]);
    }
  }

  Widget _summary(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: BallalColors.muted, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 15)),
        ]),
      );
}

class RequestSentScreen extends StatelessWidget {
  const RequestSentScreen({super.key, this.requestId});
  final String? requestId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 450),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(color: BallalColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 56),
              ),
            ),
            const SizedBox(height: 28),
            Text(l.requestSentTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(l.requestSentText, textAlign: TextAlign.center, style: const TextStyle(color: BallalColors.muted)),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => requestId == null ? context.go('/home') : context.pushReplacement('/requests/$requestId'),
              child: Text(l.seeMyRequest),
            ),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: () => context.go('/home'), child: Text(l.backHome)),
          ]),
        ),
      ),
    );
  }
}
