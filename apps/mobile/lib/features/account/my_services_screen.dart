import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';

class MyServicesScreen extends StatefulWidget {
  const MyServicesScreen({super.key});

  @override
  State<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends State<MyServicesScreen> {
  late Future<List<ProService>> _future = _load();

  Future<List<ProService>> _load() async =>
      (await ProRepo.instance.services(currentUserId!, onlyPublished: false)).where((s) => s.status != 'archived').toList();

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _edit([ProService? s]) async {
    await context.push('/my-services/edit', extra: s);
    _reload();
  }

  Future<void> _archive(ProService s) async {
    try {
      await ProRepo.instance.archiveService(s.id);
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.myServices)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: Text(l.addService),
      ),
      body: FutureBuilder<List<ProService>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorState(error: snap.error!, onRetry: _reload);
          if (!snap.hasData) return const LoadingView();
          final items = snap.data!;
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.design_services_outlined,
              title: l.noServices,
              message: l.noServicesHint,
              action: l.addService,
              onAction: () => _edit(),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final s = items[i];
                final price = formatPriceRange(s.priceMin, s.priceMax, s.priceUnit);
                return BallalCard(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  onTap: () => _edit(s),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (price.isNotEmpty) Text(price, style: const TextStyle(color: BallalColors.primary, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(s.status == 'published' ? l.published : l.draft,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: s.status == 'published' ? BallalColors.success : BallalColors.muted)),
                      ]),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) => v == 'edit' ? _edit(s) : _archive(s),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: Text(l.edit)),
                        PopupMenuItem(value: 'archive', child: Text(l.archive)),
                      ],
                    ),
                  ]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class ServiceFormScreen extends StatefulWidget {
  const ServiceFormScreen({super.key, this.service});
  final ProService? service;

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.service?.title ?? '');
  late final _description = TextEditingController(text: widget.service?.description ?? '');
  late final _priceMin = TextEditingController(text: widget.service?.priceMin?.toString() ?? '');
  late final _priceMax = TextEditingController(text: widget.service?.priceMax?.toString() ?? '');
  late final _unit = TextEditingController(text: widget.service?.priceUnit ?? '');
  late final _duration = TextEditingController(text: widget.service?.durationText ?? '');
  late String? _categoryId = widget.service?.categoryId;
  late bool _published = (widget.service?.status ?? 'published') == 'published';
  late final Future<List<Category>> _cats = CatalogRepo.instance.trades();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _description, _priceMin, _priceMax, _unit, _duration]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (!_form.currentState!.validate()) return;
    final min = int.tryParse(_priceMin.text);
    final max = int.tryParse(_priceMax.text);
    if (min != null && max != null && max < min) { showInfo(context, l.priceRangeInvalid); return; }
    setState(() => _saving = true);
    try {
      await ProRepo.instance.saveService({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'category_id': _categoryId,
        'price_min': min,
        'price_max': max,
        'price_unit': _unit.text.trim().isEmpty ? null : _unit.text.trim(),
        'duration_text': _duration.text.trim().isEmpty ? null : _duration.text.trim(),
        'status': _published ? 'published' : 'draft',
      }, id: widget.service?.id);
      if (mounted) {
        showInfo(context, l.saved);
        context.pop();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(widget.service == null ? l.addService : l.editService)),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
            controller: _title,
            maxLength: 120,
            decoration: InputDecoration(labelText: l.serviceTitle, hintText: l.serviceTitleHint),
            validator: (v) => (v ?? '').trim().length < 2 ? l.required : null,
          ),
          FutureBuilder<List<Category>>(
            future: _cats,
            builder: (context, snap) => DropdownButtonFormField<String?>(
              initialValue: _categoryId,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.category),
              items: [
                DropdownMenuItem(value: null, child: Text(l.none)),
                for (final c in snap.data ?? const <Category>[]) DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _description,
            maxLines: 4,
            maxLength: 2000,
            decoration: InputDecoration(labelText: l.description, alignLabelWithHint: true),
          ),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _priceMin,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: l.priceFrom, suffixText: 'GNF'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _priceMax,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: l.priceTo, suffixText: 'GNF'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextFormField(controller: _unit, maxLength: 40, decoration: InputDecoration(labelText: l.priceUnit, hintText: l.priceUnitHint)),
          TextFormField(controller: _duration, maxLength: 60, decoration: InputDecoration(labelText: l.duration, hintText: l.durationHint)),
          Text(l.indicativeOnly, style: const TextStyle(fontSize: 12, color: BallalColors.muted)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.publishService),
            value: _published,
            onChanged: (v) => setState(() => _published = v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(l.save),
          ),
        ]),
      ),
    );
  }
}
