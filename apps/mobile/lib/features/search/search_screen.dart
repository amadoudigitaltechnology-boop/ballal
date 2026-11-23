import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';
import 'pro_map.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialCategoryId, this.initialQuery, this.nearMe = false});
  final String? initialCategoryId;
  final String? initialQuery;
  final bool nearMe;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryCtrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  SearchFilters _filters = SearchFilters();
  final List<ProCard> _results = [];
  Object? _error;
  bool _loading = false;
  bool _hasMore = true;
  int _requestSeq = 0;
  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    _queryCtrl.text = widget.initialQuery ?? '';
    _filters.query = _queryCtrl.text;
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _init();
  }

  Future<void> _init() async {
    if (widget.initialCategoryId != null) {
      try {
        final cats = await CatalogRepo.instance.categories();
        _filters.category = cats.where((c) => c.id == widget.initialCategoryId).firstOrNull;
      } catch (_) {}
    }
    if (widget.nearMe) {
      // Laisse l'écran se construire avant d'afficher l'explication GPS.
      WidgetsBinding.instance.addPostFrameCallback((_) => _useGps());
    }
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
    });
    try {
      final items = await ProRepo.instance.search(_filters);
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _results
          ..clear()
          ..addAll(items);
        _hasMore = items.length == ProRepo.pageSize;
      });
    } catch (e) {
      if (mounted && seq == _requestSeq) setState(() => _error = e);
    } finally {
      if (mounted && seq == _requestSeq) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || _results.isEmpty) return;
    setState(() => _loading = true);
    try {
      final items = await ProRepo.instance.search(_filters, offset: _results.length);
      if (!mounted) return;
      setState(() {
        _results.addAll(items);
        _hasMore = items.length == ProRepo.pageSize;
      });
    } catch (_) {
      _hasMore = false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _filters.query = v;
      _search();
    });
  }

  /// GPS facultatif : explication, consentement, puis demande système.
  Future<void> _useGps() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.near_me_rounded, color: BallalColors.primary),
        title: Text(l.gpsExplainTitle),
        content: Text(l.gpsExplainText),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.notNow)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.allow)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final (result, lat, lng) = await GeoService.currentPosition();
      if (!mounted) return;
      if (result != GeoResult.ok) {
        showInfo(context, result == GeoResult.denied ? l.gpsDenied : l.gpsDisabled);
        return;
      }
      if (Session.instance.isSignedIn) AccountRepo.instance.recordConsent('geolocation', true);
      setState(() {
        _filters
          ..lat = lat
          ..lng = lng
          ..radiusKm ??= 10
          ..sort = 'distance';
        _showMap = true;
      });
      _search();
    } catch (e) {
      if (mounted) showInfo(context, l.gpsError);
    }
  }

  void _clearGps() {
    setState(() {
      _filters
        ..lat = null
        ..lng = null
        ..sort = 'relevance';
    });
    _search();
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FilterSheet(initial: _filters.copy()),
    );
    if (result != null) {
      setState(() => _filters = result..query = _queryCtrl.text);
      _search();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_filters.usesGps ? l.nearYou : l.navSearch),
        actions: [
          IconButton(
            tooltip: _showMap ? l.listView : l.mapView,
            onPressed: () => setState(() => _showMap = !_showMap),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(_showMap ? Icons.view_list_rounded : Icons.map_outlined, key: ValueKey(_showMap)),
            ),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _queryCtrl,
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                onSubmitted: (v) {
                  _debounce?.cancel();
                  _filters.query = v;
                  _search();
                },
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: l.searchHint,
                  suffixIcon: _queryCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l.clear,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _queryCtrl.clear();
                            _filters.query = '';
                            _search();
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Badge(
              isLabelVisible: _filters.activeCount > 0,
              label: Text('${_filters.activeCount}'),
              child: IconButton.filledTonal(
                tooltip: l.filters,
                onPressed: _openFilters,
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
          ]),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            FilterChip(
              avatar: const Icon(Icons.near_me_rounded, size: 16),
              label: Text(l.nearMe),
              selected: _filters.usesGps,
              onSelected: (v) => v ? _useGps() : _clearGps(),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text(l.availableNow),
              selected: _filters.availableOnly,
              onSelected: (v) {
                setState(() => _filters.availableOnly = v);
                _search();
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text(l.verifiedOnly),
              selected: _filters.verifiedOnly,
              onSelected: (v) {
                setState(() => _filters.verifiedOnly = v);
                _search();
              },
            ),
            if (_filters.category != null) ...[
              const SizedBox(width: 8),
              InputChip(
                label: Text(_filters.category!.name),
                onDeleted: () {
                  setState(() => _filters.category = null);
                  _search();
                },
              ),
            ],
            if (_filters.place != null) ...[
              const SizedBox(width: 8),
              InputChip(
                avatar: const Icon(Icons.place_outlined, size: 16),
                label: Text(_filters.place!.name),
                onDeleted: () {
                  setState(() => _filters.place = null);
                  _search();
                },
              ),
            ],
          ]),
        ),
        Expanded(child: _buildResults()),
      ]),
    );
  }

  Widget _buildResults() {
    if (_error != null && _results.isEmpty) return ErrorState(error: _error!, onRetry: _search);
    if (_loading && _results.isEmpty) return const LoadingView();
    if (_results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: context.l10n.noResults,
        message: context.l10n.noResultsHint,
        action: _filters.activeCount > 0 ? context.l10n.resetFilters : null,
        onAction: () {
          setState(() => _filters = SearchFilters(query: _queryCtrl.text));
          _search();
        },
      );
    }
    return RefreshIndicator(
      onRefresh: _search,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: _results.length + (_hasMore ? 1 : 0) + (_showMap ? 1 : 0),
        itemBuilder: (_, index) {
          if (_showMap && index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: FadeSlideIn(child: ProMap(pros: _results, userLat: _filters.lat, userLng: _filters.lng)),
            );
          }
          final i = _showMap ? index - 1 : index;
          if (i >= _results.length) {
            return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
          }
          final pro = _results[i];
          return FadeSlideIn(index: i % 10, child: ProListTile(pro: pro, trailing: FavoriteButton(proId: pro.id)));
        },
      ),
    );
  }
}

/// Cœur favori : ne s'affiche activé qu'après vérification serveur.
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({super.key, required this.proId, this.initial});
  final String proId;
  final bool? initial;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  bool _fav = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _fav = widget.initial!;
    } else if (Session.instance.isSignedIn) {
      ProRepo.instance.isFavorite(widget.proId).then((v) {
        if (mounted) setState(() => _fav = v);
      }).catchError((_) {});
    }
  }

  Future<void> _toggle() async {
    if (!requireAuth(context) || _busy) return;
    final next = !_fav;
    setState(() {
      _fav = next;
      _busy = true;
    });
    try {
      await ProRepo.instance.setFavorite(widget.proId, next);
    } catch (e) {
      if (mounted) {
        setState(() => _fav = !next);
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: _fav ? l.removeFavorite : l.addFavorite,
      onPressed: _toggle,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: Icon(
          _fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey(_fav),
          color: _fav ? BallalColors.danger : BallalColors.muted,
        ),
      ),
    );
  }
}

class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key, required this.initial});
  final SearchFilters initial;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late SearchFilters f = widget.initial;
  late final Future<List<Category>> _cats = CatalogRepo.instance.categories();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, controller) => ListView(controller: controller, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        Text(l.filters, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Text(l.category, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        FutureBuilder<List<Category>>(
          future: _cats,
          builder: (context, snap) {
            final cats = snap.data ?? const <Category>[];
            return DropdownButtonFormField<String?>(
              initialValue: f.category?.id,
              isExpanded: true,
              items: [
                DropdownMenuItem(value: null, child: Text(l.allCategories)),
                for (final c in cats)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(c.isFamily ? c.name : '   ${c.name}',
                        style: TextStyle(fontWeight: c.isFamily ? FontWeight.w700 : FontWeight.w400)),
                  ),
              ],
              onChanged: (id) => setState(() => f.category = cats.where((c) => c.id == id).firstOrNull),
            );
          },
        ),
        const SizedBox(height: 20),
        Text(l.zone, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
          onPressed: () async {
            final p = await pickPlace(context);
            if (p != null) setState(() => f.place = p);
          },
          icon: const Icon(Icons.place_outlined),
          label: Text(f.place?.name ?? l.anyZone),
        ),
        if (f.usesGps) ...[
          const SizedBox(height: 20),
          Text(l.radiusKm((f.radiusKm ?? 10).toString()), style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(
            value: (f.radiusKm ?? 10).toDouble(),
            min: 1,
            max: 50,
            divisions: 49,
            label: '${f.radiusKm ?? 10} km',
            onChanged: (v) => setState(() => f.radiusKm = v.round()),
          ),
        ],
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.availableNow),
          value: f.availableOnly,
          onChanged: (v) => setState(() => f.availableOnly = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.verifiedOnly),
          subtitle: Text(l.verifiedOnlyHint, style: const TextStyle(fontSize: 12)),
          value: f.verifiedOnly,
          onChanged: (v) => setState(() => f.verifiedOnly = v),
        ),
        const SizedBox(height: 8),
        Text(l.minRating, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final r in const [null, 3.0, 4.0, 4.5])
            ChoiceChip(
              label: Text(r == null ? l.any : '≥ ${r.toString().replaceAll('.', ',')} ★'),
              selected: f.minRating == r,
              onSelected: (_) => setState(() => f.minRating = r),
            ),
        ]),
        const SizedBox(height: 20),
        Text(l.sortBy, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: Text(l.sortRelevance), selected: f.sort == 'relevance', onSelected: (_) => setState(() => f.sort = 'relevance')),
          ChoiceChip(label: Text(l.sortRating), selected: f.sort == 'rating', onSelected: (_) => setState(() => f.sort = 'rating')),
          if (f.usesGps)
            ChoiceChip(label: Text(l.sortDistance), selected: f.sort == 'distance', onSelected: (_) => setState(() => f.sort = 'distance')),
        ]),
        const SizedBox(height: 28),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, SearchFilters(query: f.query)),
              child: Text(l.reset),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, f), child: Text(l.apply))),
        ]),
      ]),
    );
  }
}
