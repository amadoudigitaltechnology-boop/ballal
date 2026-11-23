import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
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

class MyServicesScreen extends StatefulWidget {
  const MyServicesScreen({super.key});

  @override
  State<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends State<MyServicesScreen> {
  late Future<List<ProService>> _future = _load();

  Future<List<ProService>> _load() => ProRepo.instance.services(currentUserId!, onlyPublished: false);

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _edit([ProService? s]) async {
    await context.push('/my-services/edit', extra: s);
    _reload();
  }

  Future<void> _setArchived(ProService s, bool archived) async {
    final l = context.l10n;
    try {
      archived ? await ProRepo.instance.archiveService(s.id) : await ProRepo.instance.restoreService(s.id);
      if (mounted) showInfo(context, archived ? l.movedToArchives : l.restored);
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget _list(List<ProService> items, {required bool archives}) {
    final l = context.l10n;
    if (items.isEmpty) {
      return archives
          ? EmptyState(icon: Icons.inventory_2_outlined, title: l.noArchives, message: l.noArchivesHint)
          : EmptyState(
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
          return FadeSlideIn(
            index: i,
            child: Opacity(
              opacity: archives ? 0.75 : 1,
              child: BallalCard(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                onTap: archives ? null : () => _edit(s),
                child: Row(children: [
                  ProPhoto(path: s.photos.firstOrNull, name: s.title, width: 64, height: 64, radius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (price.isNotEmpty) Text(price, style: const TextStyle(color: BallalColors.primary, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(archives ? l.archived : (s.status == 'published' ? l.published : l.draft),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: !archives && s.status == 'published' ? BallalColors.success : BallalColors.muted)),
                    ]),
                  ),
                  if (archives)
                    TextButton.icon(
                      onPressed: () => _setArchived(s, false),
                      icon: const Icon(Icons.unarchive_outlined, size: 18),
                      label: Text(l.restore),
                    )
                  else
                    PopupMenuButton<String>(
                      onSelected: (v) => v == 'edit' ? _edit(s) : _setArchived(s, true),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: Text(l.edit)),
                        PopupMenuItem(value: 'archive', child: Text(l.archive)),
                      ],
                    ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.myServices),
          bottom: TabBar(tabs: [Tab(text: l.tabActive), Tab(text: l.tabArchives)]),
        ),
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
            final all = snap.data!;
            return TabBarView(children: [
              _list(all.where((s) => s.status != 'archived').toList(), archives: false),
              _list(all.where((s) => s.status == 'archived').toList(), archives: true),
            ]);
          },
        ),
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
  late final Future<List<Category>> _cats = CatalogRepo.instance.trades();
  late final List<String> _existing = [...?widget.service?.photos];
  final List<String> _removed = [];
  final List<Uint8List> _newPhotos = [];
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _description, _priceMin, _priceMax, _unit, _duration]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Sélection de plusieurs photos d'un coup (10 max par service).
  Future<void> _pickPhotos() async {
    final room = 10 - _existing.length - _newPhotos.length;
    if (room <= 0) return;
    final files = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 75, limit: room);
    if (files.isEmpty) return;
    final bytes = <Uint8List>[];
    for (final f in files.take(room)) {
      bytes.add(await f.readAsBytes());
    }
    if (mounted) setState(() => _newPhotos.addAll(bytes));
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (!_form.currentState!.validate()) return;
    final min = int.tryParse(_priceMin.text);
    final max = int.tryParse(_priceMax.text);
    if (min != null && max != null && max < min) {
      showInfo(context, l.priceRangeInvalid);
      return;
    }
    setState(() => _saving = true);
    try {
      await ProRepo.instance.saveService(
        {
          'title': _title.text.trim(),
          'description': _description.text.trim(),
          'category_id': _categoryId,
          'price_min': min,
          'price_max': max,
          'price_unit': _unit.text.trim().isEmpty ? null : _unit.text.trim(),
          'duration_text': _duration.text.trim().isEmpty ? null : _duration.text.trim(),
          'status': 'published',
        },
        id: widget.service?.id,
        newPhotos: _newPhotos,
        removedPhotos: _removed,
      );
      if (mounted) {
        showInfo(context, l.saved);
        context.pop(true);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _thumb(Widget image, VoidCallback onRemove) => Stack(fit: StackFit.expand, children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: image),
        Positioned(
          right: 2,
          top: 2,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
            icon: const Icon(Icons.close, size: 16),
            onPressed: onRemove,
          ),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final count = _existing.length + _newPhotos.length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.service == null ? l.addService : l.editService)),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 110), children: [
          FieldLabel(l.servicePhotos),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final path in _existing)
                _thumb(CachedNetworkImage(imageUrl: proImageUrl(path)!, fit: BoxFit.cover), () => setState(() {
                      _existing.remove(path);
                      _removed.add(path);
                    })),
              for (final b in _newPhotos) _thumb(Image.memory(b, fit: BoxFit.cover), () => setState(() => _newPhotos.remove(b))),
              if (count < 10)
                InkWell(
                  onTap: _pickPhotos,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: BallalColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BallalColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.add_photo_alternate_outlined, color: BallalColors.primary),
                      const SizedBox(height: 4),
                      Text(l.addPhotos, textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, color: BallalColors.primary, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FieldLabel(l.serviceTitle),
          TextFormField(
            controller: _title,
            maxLength: 120,
            buildCounter: noCounter,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: l.serviceTitleHint),
            validator: (v) => (v ?? '').trim().length < 2 ? l.required : null,
          ),
          const SizedBox(height: 12),
          FieldLabel(l.category),
          FutureBuilder<List<Category>>(
            future: _cats,
            builder: (context, snap) => DropdownButtonFormField<String?>(
              initialValue: _categoryId,
              isExpanded: true,
              decoration: const InputDecoration(),
              items: [
                DropdownMenuItem(value: null, child: Text(l.none)),
                for (final c in snap.data ?? const <Category>[]) DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          ),
          const SizedBox(height: 12),
          FieldLabel(l.description),
          TextFormField(
            controller: _description,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            buildCounter: noCounter,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: l.serviceDescriptionHint),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FieldLabel(l.priceFrom),
                TextFormField(
                  controller: _priceMin,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: '50 000', suffixText: 'GNF'),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FieldLabel(l.priceTo),
                TextFormField(
                  controller: _priceMax,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: '150 000', suffixText: 'GNF'),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          FieldLabel(l.priceUnit),
          TextFormField(controller: _unit, maxLength: 40, buildCounter: noCounter, decoration: InputDecoration(hintText: l.priceUnitHint)),
          const SizedBox(height: 12),
          FieldLabel(l.duration),
          TextFormField(controller: _duration, maxLength: 60, buildCounter: noCounter, decoration: InputDecoration(hintText: l.durationHint)),
          const SizedBox(height: 8),
          Text(l.indicativeOnly, style: const TextStyle(fontSize: 12, color: BallalColors.muted)),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(l.saveAndPublish),
            ),
          ),
        ),
      ),
    );
  }
}
