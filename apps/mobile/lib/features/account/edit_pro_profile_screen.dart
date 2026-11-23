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

/// Profil professionnel : saisie libre, enregistrement = publication automatique.
class EditProProfileScreen extends StatefulWidget {
  const EditProProfileScreen({super.key});

  @override
  State<EditProProfileScreen> createState() => _EditProProfileScreenState();
}

class _EditProProfileScreenState extends State<EditProProfileScreen> {
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
  String? _logoPath;
  String? _coverPath;
  bool _uploadingLogo = false;
  bool _uploadingCover = false;
  Place? _base;
  String? _baseLabel;
  final Map<String, Place> _areas = {};
  final Set<String> _categoryIds = {};
  String? _primaryCategory;
  final List<_DayHours> _hours = List.generate(7, (_) => _DayHours());
  List<Map<String, dynamic>> _portfolio = [];
  int _portfolioUploading = 0;

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
        CatalogRepo.instance.places(force: true),
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
        _logoPath = p['logo_path'] as String?;
        _coverPath = p['cover_path'] as String?;
        _base = places.where((x) => x.id == p['location_id']).firstOrNull;
        if (_base != null) _baseLabel = await CatalogRepo.instance.label(_base!);
        for (final a in (p['service_areas'] as List? ?? const [])) {
          final place = places.where((x) => x.id == (a as Map<String, dynamic>)['location_id']).firstOrNull;
          if (place != null) _areas[place.id] = place;
        }
        for (final pc in (p['professional_categories'] as List? ?? const [])) {
          _categoryIds.add((pc as Map<String, dynamic>)['category_id'] as String);
        }
        _primaryCategory = _categoryIds.firstOrNull;
      }
      if (_name.text.isEmpty) _name.text = Session.instance.fullName ?? '';
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
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: logo ? 800 : 1920, imageQuality: 80);
    if (file == null) return;
    setState(() => logo ? _uploadingLogo = true : _uploadingCover = true);
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
    } finally {
      if (mounted) setState(() => logo ? _uploadingLogo = false : _uploadingCover = false);
    }
  }

  /// Plusieurs photos de réalisations en une seule sélection.
  Future<void> _addPortfolio() async {
    final room = 30 - _portfolio.length;
    if (room <= 0) return;
    final files = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 75, limit: room);
    if (files.isEmpty) return;
    setState(() => _portfolioUploading = files.length);
    for (final file in files.take(room)) {
      try {
        final path = await AccountRepo.instance.uploadPublicImage('pro-media', await file.readAsBytes(), 'portfolio');
        final row = await supa.from('portfolio_items')
            .insert({'professional_id': currentUserId, 'storage_path': path}).select('id, storage_path').single();
        if (mounted) setState(() => _portfolio.add(row));
      } catch (e) {
        if (mounted) showError(context, e);
      } finally {
        if (mounted) setState(() => _portfolioUploading--);
      }
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
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TradesSheet(all: _allCategories, initial: _categoryIds),
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

  Future<void> _chooseBase() async {
    final p = await pickPlace(context, title: context.l10n.baseZone);
    if (p == null) return;
    final label = await CatalogRepo.instance.label(p);
    setState(() {
      _base = p;
      _baseLabel = label;
    });
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (_name.text.trim().isEmpty) {
      showInfo(context, l.nameRequired);
      return;
    }
    String? phone, whatsapp;
    if (_phone.text.trim().isNotEmpty) {
      phone = normalizeGuineaPhone(_phone.text);
      if (phone == null) {
        showInfo(context, l.phoneInvalid);
        return;
      }
    }
    if (_whatsapp.text.trim().isNotEmpty) {
      whatsapp = normalizeGuineaPhone(_whatsapp.text);
      if (whatsapp == null) {
        showInfo(context, l.phoneInvalid);
        return;
      }
    }
    for (final d in _hours.where((d) => d.enabled)) {
      if (_hhmm(d.closes).compareTo(_hhmm(d.opens)) <= 0) {
        showInfo(context, l.hoursInvalid);
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await ProRepo.instance.saveMyProfile(
        profile: {
          'display_name': _name.text.trim(),
          // Le métier affiché = le métier principal choisi dans la liste (plus de saisie en double).
          'headline': _allCategories.where((c) => c.id == _primaryCategory).firstOrNull?.name ?? _headline.text.trim(),
          'description': _description.text.trim(),
          'pro_type': _proType,
          'experience_years': int.tryParse(_experience.text),
          'skills': _skills.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).take(20).toList(),
          'languages': _languages.toList(),
          'price_hint': _priceHint.text.trim().isEmpty ? null : _priceHint.text.trim(),
          'location_id': _base?.id,
          'logo_path': _logoPath,
          'cover_path': _coverPath,
          'is_published': true, // publication automatique à l'enregistrement
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
      showInfo(context, l.profileSavedPublished);
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

  Widget _section(String title, List<Widget> children, {IconData? icon}) {
    return FadeSlideIn(
      child: BallalCard(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: BallalColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: BallalColors.primary),
              ),
              const SizedBox(width: 10),
            ],
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ]),
          const SizedBox(height: 12),
          ...children,
        ]),
      ),
    );
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

    return Scaffold(
      appBar: AppBar(title: Text(l.myProProfile)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), children: [
        // ─── Couverture + photo de profil ───
        FadeSlideIn(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(clipBehavior: Clip.none, children: [
              GestureDetector(
                onTap: _uploadingCover ? null : () => _pickImage(false),
                child: AspectRatio(
                  aspectRatio: 16 / 9, // toute image est recadrée automatiquement à ce format
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(kRadius),
                      gradient: const LinearGradient(colors: [BallalColors.primary, BallalColors.primaryDark]),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(fit: StackFit.expand, children: [
                      if (_coverPath != null) CachedNetworkImage(imageUrl: proImageUrl(_coverPath)!, fit: BoxFit.cover),
                      if (_coverPath == null)
                        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.add_photo_alternate_outlined, color: Colors.white, size: 36),
                          const SizedBox(height: 6),
                          Text(l.addCover, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ]),
                      if (_uploadingCover) Container(color: Colors.black38, child: const Center(child: CircularProgressIndicator())),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.edit, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(l.change, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                bottom: -36,
                child: GestureDetector(
                  onTap: _uploadingLogo ? null : () => _pickImage(true),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12)],
                    ),
                    child: Stack(children: [
                      Avatar(url: proImageUrl(_logoPath), name: _name.text, size: 84),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(color: BallalColors.accent, shape: BoxShape.circle),
                          child: _uploadingLogo
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.photo_camera, color: Colors.white, size: 14),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 44),
            Text(l.coverHint, style: const TextStyle(fontSize: 12, color: BallalColors.muted)),
            const SizedBox(height: 16),
          ]),
        ),

        _section(l.identity, icon: Icons.badge_outlined, [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'independent', label: Text(l.typeIndependent), icon: const Icon(Icons.person_outline)),
              ButtonSegment(value: 'company', label: Text(l.typeCompany), icon: const Icon(Icons.business_outlined)),
            ],
            selected: {_proType},
            onSelectionChanged: (s) => setState(() => _proType = s.first),
          ),
          const SizedBox(height: 14),
          FieldLabel(l.proDisplayName),
          TextField(
            controller: _name,
            maxLength: 120,
            buildCounter: noCounter,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: l.proDisplayNameHint, prefixIcon: const Icon(Icons.storefront_outlined)),
          ),
          const SizedBox(height: 12),
          FieldLabel(l.description),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 8,
            maxLength: 3000,
            buildCounter: noCounter,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: l.proDescriptionHint),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FieldLabel(l.experienceYears),
                TextField(
                  controller: _experience,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                  decoration: const InputDecoration(hintText: '5', prefixIcon: Icon(Icons.timeline)),
                ),
              ]),
            ),
          ]),
        ]),

        _section(l.tradesAndCategories, icon: Icons.category_outlined, [
          if (catNames.isEmpty)
            Text(l.noTradeYet, style: const TextStyle(color: BallalColors.muted))
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in catNames)
                ChoiceChip(
                  label: Text(c.name),
                  selected: c.id == _primaryCategory,
                  avatar: c.id == _primaryCategory ? const Icon(Icons.star_rounded, size: 16, color: BallalColors.accent) : null,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _primaryCategory = c.id),
                ),
            ]),
          if (catNames.length > 1) ...[
            const SizedBox(height: 6),
            Text(l.tapToSetPrimary, style: const TextStyle(fontSize: 12, color: BallalColors.muted)),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _chooseCategories,
            icon: const Icon(Icons.add),
            label: Text(catNames.isEmpty ? l.chooseTrades : l.editTrades),
          ),
          const SizedBox(height: 14),
          FieldLabel(l.specialties, note: l.optional),
          TextField(
            controller: _skills,
            decoration: InputDecoration(hintText: l.skillsHint, prefixIcon: const Icon(Icons.bolt_outlined)),
          ),
        ]),

        _section(l.serviceZones, icon: Icons.place_outlined, [
          FieldLabel(l.baseZone),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _chooseBase,
            child: InputDecorator(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.home_work_outlined), suffixIcon: Icon(Icons.chevron_right)),
              child: Text(_baseLabel ?? l.chooseZone,
                  style: TextStyle(color: _baseLabel == null ? const Color(0xFF94A3B8) : BallalColors.text)),
            ),
          ),
          const SizedBox(height: 6),
          Text(l.baseZoneHint, style: const TextStyle(fontSize: 12, color: BallalColors.muted)),
          const SizedBox(height: 12),
          FieldLabel(l.otherZones),
          Wrap(spacing: 8, runSpacing: 8, children: [
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
        ]),

        _section(l.portfolio, icon: Icons.photo_library_outlined, [
          Text(l.portfolioHint, style: const TextStyle(fontSize: 12, color: BallalColors.muted)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final item in _portfolio)
                Stack(fit: StackFit.expand, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(imageUrl: proImageUrl(item['storage_path'] as String)!, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: IconButton(
                      tooltip: l.remove,
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => _removePortfolio(item),
                    ),
                  ),
                ]),
              for (var i = 0; i < _portfolioUploading; i++)
                Container(
                  decoration: BoxDecoration(color: BallalColors.field, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              if (_portfolio.length < 30)
                InkWell(
                  onTap: _portfolioUploading > 0 ? null : _addPortfolio,
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
        ]),

        _section(l.openingHours, icon: Icons.schedule_outlined, [
          for (var i = 0; i < 7; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Switch(value: _hours[i].enabled, onChanged: (v) => setState(() => _hours[i].enabled = v)),
                const SizedBox(width: 6),
                SizedBox(width: 82, child: Text(days[i], style: const TextStyle(fontWeight: FontWeight.w600))),
                if (_hours[i].enabled) ...[
                  _TimeChip(
                    value: _hhmm(_hours[i].opens),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: _hours[i].opens);
                      if (t != null) setState(() => _hours[i].opens = t);
                    },
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('–')),
                  _TimeChip(
                    value: _hhmm(_hours[i].closes),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: _hours[i].closes);
                      if (t != null) setState(() => _hours[i].closes = t);
                    },
                  ),
                ] else
                  Text(l.closed, style: const TextStyle(color: BallalColors.muted)),
              ]),
            ),
        ]),

        _section(l.indicativePrices, icon: Icons.payments_outlined, [
          TextField(
            controller: _priceHint,
            maxLength: 120,
            buildCounter: noCounter,
            decoration: InputDecoration(hintText: l.priceHintExample),
          ),
          const SizedBox(height: 6),
          Text(l.indicativeOnly, style: const TextStyle(fontSize: 12, color: BallalColors.muted)),
        ]),

        _section(l.languages, icon: Icons.translate_rounded, [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in const {'fr': 'Français', 'ff': 'Pular', 'sus': 'Soussou', 'man': 'Malinké', 'en': 'English'}.entries)
              FilterChip(
                label: Text(e.value),
                selected: _languages.contains(e.key),
                onSelected: (v) => setState(() => v ? _languages.add(e.key) : _languages.remove(e.key)),
              ),
          ]),
        ]),

        _section(l.contacts, icon: Icons.call_outlined, [
          FieldLabel(l.phoneLabel),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: '620 00 00 00', prefixIcon: Icon(Icons.call_outlined)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.showPhone),
            value: _showPhone,
            onChanged: (v) => setState(() => _showPhone = v),
          ),
          const FieldLabel('WhatsApp'),
          TextField(
            controller: _whatsapp,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: '620 00 00 00', prefixIcon: Icon(Icons.chat_outlined)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.showWhatsapp),
            value: _showWhatsapp,
            onChanged: (v) => setState(() => _showWhatsapp = v),
          ),
          Text(l.contactPrivacyHint, style: const TextStyle(fontSize: 12, color: BallalColors.muted)),
        ]),
      ]),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          color: Colors.white,
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: Text(l.saveAndPublish),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.value, required this.onTap});
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: BallalColors.field, borderRadius: BorderRadius.circular(10)),
        child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Choix des métiers : recherche + pastilles par famille (5 maximum).
class _TradesSheet extends StatefulWidget {
  const _TradesSheet({required this.all, required this.initial});
  final List<Category> all;
  final Set<String> initial;

  @override
  State<_TradesSheet> createState() => _TradesSheetState();
}

class _TradesSheetState extends State<_TradesSheet> {
  late final Set<String> _selected = {...widget.initial};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final families = widget.all.where((c) => c.isFamily).toList();
    final query = _q.toLowerCase();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (_, controller) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.chooseTrades, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                Text(l.tradesCount(_selected.length.toString()), style: const TextStyle(color: BallalColors.muted, fontSize: 13)),
              ]),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
              onPressed: () => Navigator.pop(context, _selected),
              child: Text(l.validate),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v.trim()),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.searchTrade),
          ),
        ),
        Expanded(
          child: ListView(controller: controller, padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
            for (final f in families)
              Builder(builder: (context) {
                final trades = widget.all
                    .where((c) => c.parentId == f.id && (query.isEmpty || c.name.toLowerCase().contains(query) ||
                        f.name.toLowerCase().contains(query)))
                    .toList();
                if (trades.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(categoryIcon(f.icon), size: 18, color: BallalColors.accent),
                      const SizedBox(width: 6),
                      Text(f.name, style: const TextStyle(fontWeight: FontWeight.w800, color: BallalColors.primaryDark)),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final t in trades)
                        FilterChip(
                          label: Text(t.name),
                          selected: _selected.contains(t.id),
                          onSelected: (v) {
                            if (v && _selected.length >= 5) {
                              showInfo(context, l.maxTrades);
                              return;
                            }
                            setState(() => v ? _selected.add(t.id) : _selected.remove(t.id));
                          },
                        ),
                    ]),
                  ]),
                );
              }),
          ]),
        ),
      ]),
    );
  }
}
