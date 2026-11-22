import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/formatters.dart';
import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';

class _DayHours {
  bool enabled = false;
  TimeOfDay opens = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay closes = const TimeOfDay(hour: 18, minute: 0);
}

String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay _parseTime(String s) {
  final parts = s.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

/// Création / modification du profil professionnel (cahier §3 et §4).
class EditProProfileScreen extends StatefulWidget {
  const EditProProfileScreen({super.key});

  @override
  State<EditProProfileScreen> createState() => _EditProProfileScreenState();
}

class _EditProProfileScreenState extends State<EditProProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _headline = TextEditingController();
  final _description = TextEditingController();
  final _experience = TextEditingController();
  final _skills = TextEditingController();
  final _priceHint = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();

  String _proType = 'independent';
  Set<String> _languages = {'fr'};
  bool _showPhone = true;
  bool _showWhatsapp = true;
  bool _published = false;
  String? _logoPath;
  String? _coverPath;
  Place? _base;
  final Map<String, Place> _areas = {};
  final Set<String> _categoryIds = {};
  String? _primaryCategory;
  final List<_DayHours> _hours = List.generate(7, (_) => _DayHours());
  List<Map<String, dynamic>> _portfolio = [];

  List<Category> _allCategories = [];
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _headline, _description, _experience, _skills, _priceHint, _phone, _whatsapp]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!Session.instance.hasProRole) await Session.instance.activateRole('professional');
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        ProRepo.instance.myProfile(),
        ProRepo.instance.myContacts(),
        CatalogRepo.instance.categories(),
        CatalogRepo.instance.places(),
        supa.from('opening_hours').select('weekday, opens, closes').eq('professional_id', currentUserId!),
        supa.from('portfolio_items').select('id, storage_path').eq('professional_id', currentUserId!).order('created_at'),
      ]);
      final p = results[0] as Map<String, dynamic>?;
      final c = results[1] as Map<String, dynamic>?;
      _allCategories = results[2] as List<Category>;
      final places = results[3] as List<Place>;
      final hours = (results[4] as List).cast<Map<String, dynamic>>();
      _portfolio = (results[5] as List).cast<Map<String, dynamic>>();

      if (p != null) {
        _name.text = (p['display_name'] as String?) ?? '';
        _headline.text = (p['headline'] as String?) ?? '';
        _description.text = (p['description'] as String?) ?? '';
        _experience.text = p['experience_years']?.toString() ?? '';
        _skills.text = ((p['skills'] as List?) ?? const []).join(', ');
        _priceHint.text = (p['price_hint'] as String?) ?? '';
        _proType = (p['pro_type'] as String?) ?? 'independent';
        _languages = ((p['languages'] as List?) ?? const ['fr']).map((e) => e.toString()).toSet();
        _published = (p['is_published'] as bool?) ?? false;
        _logoPath = p['logo_path'] as String?;
        _coverPath = p['cover_path'] as String?;
        _base = places.where((x) => x.id == p['location_id']).firstOrNull;
        for (final a in (p['service_areas'] as List? ?? const [])) {
          final place = places.where((x) => x.id == (a as Map<String, dynamic>)['location_id']).firstOrNull;
          if (place != null) _areas[place.id] = place;
        }
        for (final pc in (p['professional_categories'] as List? ?? const [])) {
          _categoryIds.add((pc as Map<String, dynamic>)['category_id'] as String);
        }
        _primaryCategory = _categoryIds.firstOrNull;
      }
      if (c != null) {
        _phone.text = (c['phone'] as String?) ?? '';
        _whatsapp.text = (c['whatsapp'] as String?) ?? '';
        _showPhone = (c['show_phone'] as bool?) ?? true;
        _showWhatsapp = (c['show_whatsapp'] as bool?) ?? true;
      }
      for (final h in hours) {
        final d = _hours[(h['weekday'] as num).toInt()];
        d.enabled = true;
        d.opens = _parseTime(h['opens'] as String);
        d.closes = _parseTime(h['closes'] as String);
      }
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickImage(bool logo) async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: logo ? 600 : 1600, imageQuality: 75);
    if (file == null) return;
    try {
      final path = await AccountRepo.instance.uploadPublicImage('pro-media', await file.readAsBytes(), logo ? 'logo' : 'cover');
      setState(() {
        if (logo) {
          _logoPath = path;
        } else {
          _coverPath = path;
        }
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _addPortfolio() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 72);
    if (file == null) return;
    try {
      final path = await AccountRepo.instance.uploadPublicImage('pro-media', await file.readAsBytes(), 'portfolio');
      final row = await supa.from('portfolio_items')
          .insert({'professional_id': currentUserId, 'storage_path': path}).select('id, storage_path').single();
      setState(() => _portfolio.add(row));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _removePortfolio(Map<String, dynamic> item) async {
    try {
      await supa.from('portfolio_items').delete().eq('id', item['id'] as String);
      await supa.storage.from('pro-media').remove([item['storage_path'] as String]);
      setState(() => _portfolio.remove(item));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _chooseCategories() async {
    final selected = Set<String>.from(_categoryIds);
    final families = _allCategories.where((c) => c.isFamily).toList();
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          builder: (_, controller) => Column(children: [
            ListTile(
              title: Text(context.l10n.chooseTrades, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(context.l10n.maxTrades),
              trailing: FilledButton(onPressed: () => Navigator.pop(ctx, selected), child: Text(context.l10n.ok)),
            ),
            Expanded(
              child: ListView(controller: controller, children: [
                for (final f in families) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w800, color: BallalColors.primary)),
                  ),
                  for (final t in _allCategories.where((c) => c.parentId == f.id))
                    CheckboxListTile(
                      dense: true,
                      title: Text(t.name),
                      value: selected.contains(t.id),
                      onChanged: (v) => setSheet(() {
                        if (v == true && selected.length < 5) {
                          selected.add(t.id);
                        } else {
                          selected.remove(t.id);
                        }
                      }),
                    ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _categoryIds
          ..clear()
          ..addAll(result);
        if (!_categoryIds.contains(_primaryCategory)) _primaryCategory = _categoryIds.firstOrNull;
      });
    }
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (!_form.currentState!.validate()) return;
    if (_published && (_base == null || _categoryIds.isEmpty)) {
      showInfo(context, l.errProfileIncomplete);
      return;
    }
    String? phone, whatsapp;
    if (_phone.text.trim().isNotEmpty) {
      phone = normalizeGuineaPhone(_phone.text);
      if (phone == null) { showInfo(context, l.phoneInvalid); return; }
    }
    if (_whatsapp.text.trim().isNotEmpty) {
      whatsapp = normalizeGuineaPhone(_whatsapp.text);
      if (whatsapp == null) { showInfo(context, l.phoneInvalid); return; }
    }
    for (final d in _hours.where((d) => d.enabled)) {
      if (_hhmm(d.closes).compareTo(_hhmm(d.opens)) <= 0) { showInfo(context, l.hoursInvalid); return; }
    }
    setState(() => _saving = true);
    try {
      await ProRepo.instance.saveMyProfile(
        profile: {
          'display_name': _name.text.trim(),
          'headline': _headline.text.trim(),
          'description': _description.text.trim(),
          'pro_type': _proType,
          'experience_years': int.tryParse(_experience.text),
          'skills': _skills.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).take(20).toList(),
          'languages': _languages.toList(),
          'price_hint': _priceHint.text.trim().isEmpty ? null : _priceHint.text.trim(),
          'location_id': _base?.id,
          'logo_path': _logoPath,
          'cover_path': _coverPath,
          'is_published': _published,
        },
        contacts: {'phone': phone, 'whatsapp': whatsapp, 'show_phone': _showPhone, 'show_whatsapp': _showWhatsapp},
        categoryIds: _categoryIds,
        areaIds: _areas.keys.toSet(),
        primaryCategoryId: _primaryCategory,
      );
      final uid = currentUserId!;
      await supa.from('opening_hours').delete().eq('professional_id', uid);
      final rows = [
        for (var i = 0; i < 7; i++)
          if (_hours[i].enabled)
            {'professional_id': uid, 'weekday': i, 'opens': _hhmm(_hours[i].opens), 'closes': _hhmm(_hours[i].closes)},
      ];
      if (rows.isNotEmpty) await supa.from('opening_hours').insert(rows);
      if (!mounted) return;
      showInfo(context, l.saved);
      if (Navigator.of(context).canPop()) {
        context.pop();
      } else {
        context.go('/home');
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
    if (_loading) return Scaffold(appBar: AppBar(title: Text(l.myProProfile)), body: const LoadingView());
    if (_error != null) {
      return Scaffold(appBar: AppBar(title: Text(l.myProProfile)), body: ErrorState(error: _error!, onRetry: _load));
    }
    final days = [l.dayMon, l.dayTue, l.dayWed, l.dayThu, l.dayFri, l.daySat, l.daySun];
    final catNames = _allCategories.where((c) => _categoryIds.contains(c.id)).toList();
    Widget title(String t) => Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.myProProfile)),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          // Photo / logo et couverture
          SizedBox(
            height: 150,
            child: Stack(clipBehavior: Clip.none, children: [
              GestureDetector(
                onTap: () => _pickImage(false),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(colors: [BallalColors.primary, BallalColors.primaryDark]),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _coverPath != null
                      ? CachedNetworkImage(imageUrl: proImageUrl(_coverPath)!, fit: BoxFit.cover)
                      : Center(child: Text(l.addCover, style: const TextStyle(color: Colors.white))),
                ),
              ),
              Positioned(
                left: 16,
                bottom: 0,
                child: GestureDetector(
                  onTap: () => _pickImage(true),
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                    child: Avatar(url: proImageUrl(_logoPath), name: _name.text, size: 72),
                  ),
                ),
              ),
            ]),
          ),
          Text(l.tapToChangePhotos, style: const TextStyle(fontSize: 12, color: BallalColors.muted)),
          title(l.identity),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'independent', label: Text(l.typeIndependent), icon: const Icon(Icons.person_outline)),
              ButtonSegment(value: 'company', label: Text(l.typeCompany), icon: const Icon(Icons.business_outlined)),
            ],
            selected: {_proType},
            onSelectionChanged: (s) => setState(() => _proType = s.first),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            maxLength: 120,
            decoration: InputDecoration(labelText: l.proDisplayName),
            validator: (v) => (v ?? '').trim().length < 2 ? l.required : null,
          ),
          TextFormField(
            controller: _headline,
            maxLength: 120,
            decoration: InputDecoration(labelText: l.mainTrade, hintText: l.mainTradeHint),
            validator: (v) => (v ?? '').trim().length < 2 ? l.required : null,
          ),
          TextFormField(
            controller: _description,
            maxLines: 5,
            maxLength: 3000,
            decoration: InputDecoration(labelText: l.description, hintText: l.proDescriptionHint, alignLabelWithHint: true),
          ),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _experience,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                decoration: InputDecoration(labelText: l.experienceYears),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextFormField(controller: _skills, decoration: InputDecoration(labelText: l.skills, hintText: l.skillsHint)),
          title(l.tradesAndCategories),
          OutlinedButton.icon(
            onPressed: _chooseCategories,
            icon: const Icon(Icons.category_outlined),
            label: Text(catNames.isEmpty ? l.chooseTrades : l.tradesSelected(catNames.length.toString())),
          ),
          Wrap(spacing: 6, children: [
            for (final c in catNames)
              ChoiceChip(
                label: Text(c.name),
                selected: c.id == _primaryCategory,
                tooltip: l.primaryTrade,
                onSelected: (_) => setState(() => _primaryCategory = c.id),
              ),
          ]),
          title(l.languages),
          Wrap(spacing: 6, children: [
            for (final e in const {'fr': 'Français', 'ff': 'Pular', 'sus': 'Soussou', 'man': 'Malinké', 'en': 'English'}.entries)
              FilterChip(
                label: Text(e.value),
                selected: _languages.contains(e.key),
                onSelected: (v) => setState(() => v ? _languages.add(e.key) : _languages.remove(e.key)),
              ),
          ]),
          title(l.serviceZones),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading: const Icon(Icons.home_work_outlined, color: BallalColors.primary),
            title: Text(_base?.name ?? l.baseZone),
            subtitle: Text(l.baseZoneHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final p = await pickPlace(context, title: l.baseZone);
              if (p != null) setState(() => _base = p);
            },
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final a in _areas.values) InputChip(label: Text(a.name), onDeleted: () => setState(() => _areas.remove(a.id))),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: Text(l.addZone),
              onPressed: () async {
                final p = await pickPlace(context, title: l.addZone);
                if (p != null) setState(() => _areas[p.id] = p);
              },
            ),
          ]),
          title(l.openingHours),
          for (var i = 0; i < 7; i++)
            Row(children: [
              SizedBox(
                width: 110,
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(days[i]),
                  value: _hours[i].enabled,
                  onChanged: (v) => setState(() => _hours[i].enabled = v ?? false),
                ),
              ),
              if (_hours[i].enabled) ...[
                TextButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: _hours[i].opens);
                    if (t != null) setState(() => _hours[i].opens = t);
                  },
                  child: Text(_hhmm(_hours[i].opens)),
                ),
                const Text('–'),
                TextButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: _hours[i].closes);
                    if (t != null) setState(() => _hours[i].closes = t);
                  },
                  child: Text(_hhmm(_hours[i].closes)),
                ),
              ] else
                Text(l.closed, style: const TextStyle(color: BallalColors.muted)),
            ]),
          title(l.indicativePrices),
          TextFormField(
            controller: _priceHint,
            maxLength: 120,
            decoration: InputDecoration(hintText: l.priceHintExample, helperText: l.indicativeOnly),
          ),
          title(l.contacts),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: l.phoneLabel, prefixIcon: const Icon(Icons.call_outlined)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.showPhone),
            value: _showPhone,
            onChanged: (v) => setState(() => _showPhone = v),
          ),
          TextFormField(
            controller: _whatsapp,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'WhatsApp', prefixIcon: Icon(Icons.chat_outlined)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.showWhatsapp),
            value: _showWhatsapp,
            onChanged: (v) => setState(() => _showWhatsapp = v),
          ),
          Text(l.contactPrivacyHint, style: const TextStyle(fontSize: 12, color: BallalColors.muted)),
          title(l.portfolio),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final item in _portfolio)
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: proImageUrl(item['storage_path'] as String)!,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    tooltip: l.remove,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => _removePortfolio(item),
                  ),
                ),
              ]),
            if (_portfolio.length < 30)
              InkWell(
                onTap: _addPortfolio,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BallalColors.border),
                  ),
                  child: const Icon(Icons.add_photo_alternate_outlined, color: BallalColors.primary),
                ),
              ),
          ]),
          title(l.visibility),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.publishProfile),
            subtitle: Text(_published ? l.publishedHint : l.unpublishedHint),
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
