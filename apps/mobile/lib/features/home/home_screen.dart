import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/formatters.dart';
import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../core/unread.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';

/// Accueil unique (client ou pro) : tous les professionnels publiés, comme sur la maquette.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const ClientHome();
}

class _Bell extends StatelessWidget {
  const _Bell();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Unread.instance,
      builder: (context, _) => IconButton(
        tooltip: context.l10n.notifications,
        onPressed: () {
          if (requireAuth(context)) context.push('/notifications');
        },
        icon: Badge(
          isLabelVisible: Unread.instance.notifications > 0,
          label: Text('${Unread.instance.notifications}'),
          child: const Icon(Icons.notifications_none_rounded, size: 28),
        ),
      ),
    );
  }
}

/// Icône engrenage en haut à droite → Paramètres.
class _Gear extends StatelessWidget {
  const _Gear();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.settings,
      onPressed: () {
        if (requireAuth(context)) context.push('/settings');
      },
      icon: const Icon(Icons.settings_outlined, size: 26),
    );
  }
}

// ═════════════ Accueil client ═════════════
class ClientHome extends StatefulWidget {
  const ClientHome({super.key});

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  Place? _zone;
  late Future<List<Category>> _families;
  late Future<List<ProCard>> _reco;
  Future<List<ServiceRequest>>? _recent;
  final List<ProCard> _feed = [];
  List<Ad> _ads = const [];
  bool _feedLoading = false;
  bool _feedHasMore = true;
  Object? _feedError;

  @override
  void initState() {
    super.initState();
    _families = CatalogRepo.instance.families();
    _reco = Future.value(const []);
    _restoreZone();
    _loadFeed(reset: true);
    AdsRepo.instance.active().then((a) {
      if (mounted) setState(() => _ads = a);
    });
  }

  /// Tous les professionnels publiés, toutes zones confondues, par pages.
  Future<void> _loadFeed({bool reset = false}) async {
    if (_feedLoading) return;
    setState(() {
      _feedLoading = true;
      _feedError = null;
      if (reset) {
        _feed.clear();
        _feedHasMore = true;
      }
    });
    try {
      final page = await ProRepo.instance.search(SearchFilters(sort: 'rating'), offset: _feed.length);
      if (!mounted) return;
      setState(() {
        _feed.addAll(page.where((p) => !_feed.any((x) => x.id == p.id)));
        _feedHasMore = page.length >= ProRepo.pageSize;
      });
    } catch (e) {
      if (mounted) setState(() => _feedError = e);
    } finally {
      if (mounted) setState(() => _feedLoading = false);
    }
  }

  Future<void> _restoreZone() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('zone_id');
    Place? zone;
    try {
      final places = await CatalogRepo.instance.places();
      zone = places.where((p) => p.id == id).firstOrNull ??
          places.where((p) => p.level == 'city' && p.name == 'Conakry').firstOrNull;
    } catch (_) {}
    if (!mounted) return;
    setState(() => _zone = zone);
    _reload();
  }

  void _reload() {
    setState(() {
      _families = CatalogRepo.instance.families();
      _reco = ProRepo.instance.recommend(place: _zone);
      _recent = Session.instance.isSignedIn && Session.instance.isClient
          ? RequestRepo.instance.mine(asPro: false).then((r) => r.take(3).toList())
          : null;
    });
  }

  Future<void> _chooseZone() async {
    final p = await pickPlace(context);
    if (p == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('zone_id', p.id);
    setState(() => _zone = p);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _loadFeed(reset: true);
          },
          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(children: [const BallalLogo(), const Spacer(), const _Bell(), const _Gear()]),
            ),
            ListenableBuilder(
              listenable: Session.instance,
              builder: (context, _) => !(Session.instance.isSignedIn && Session.instance.hasProRole)
                  ? const SizedBox.shrink()
                  : FadeSlideIn(
                child: BallalCard(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  onTap: () => context.push('/pro-dashboard'),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: BallalColors.accentSoft, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.dashboard_customize_outlined, color: BallalColors.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.proSpace, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(l.proSpaceHint, style: const TextStyle(fontSize: 12, color: BallalColors.muted)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(Icons.place_rounded, size: 18, color: BallalColors.primary),
                  label: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_zone?.name ?? l.chooseZone, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  ]),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: BallalColors.border),
                  shape: const StadiumBorder(),
                  onPressed: _chooseZone,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.go('/search'),
                child: IgnorePointer(
                  child: TextField(
                    decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.searchHint),
                  ),
                ),
              ),
            ),
            _Banner(onTap: () => context.go('/search?near=1')),
            SectionHeader(title: l.categories),
            FutureBuilder<List<Category>>(
              future: _families,
              builder: (context, snap) {
                if (snap.hasError) return ErrorState(error: snap.error!, onRetry: _reload);
                if (!snap.hasData) return const SizedBox(height: 120, child: LoadingView());
                final fams = snap.data!;
                final shown = fams.take(5).toList();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.05,
                    children: [
                      for (final c in shown)
                        _CategoryTile(
                          icon: categoryIcon(c.icon),
                          label: c.name,
                          onTap: () => context.go('/search?category=${c.id}'),
                        ),
                      _CategoryTile(
                        icon: Icons.apps_rounded,
                        label: l.others,
                        onTap: () => _allCategories(fams),
                      ),
                    ],
                  ),
                );
              },
            ),
            SectionHeader(title: l.recommendedForYou, action: l.seeAll, onAction: () => context.go('/search')),
            SizedBox(
              height: 236,
              child: FutureBuilder<List<ProCard>>(
                future: _reco,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) return const LoadingView();
                  final items = snap.data ?? const [];
                  if (items.isEmpty) {
                    return Center(
                      child: Text(l.noRecoYet, textAlign: TextAlign.center, style: const TextStyle(color: BallalColors.muted)),
                    );
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => FadeSlideIn(
                      index: i,
                      child: ProRecoCard(
                        pro: items[i],
                        onTap: () {
                          ProRepo.instance.logRecoEvent(items[i].id, 'click', position: i);
                          context.push('/pro/${items[i].id}');
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_recent != null)
              FutureBuilder<List<ServiceRequest>>(
                future: _recent,
                builder: (context, snap) {
                  final items = snap.data ?? const [];
                  if (items.isEmpty) return const SizedBox.shrink();
                  return Column(children: [
                    SectionHeader(title: l.recentRequests, action: l.seeAll, onAction: () => context.push('/requests')),
                    for (final r in items)
                      BallalCard(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                        onTap: () => context.push('/requests/${r.id}'),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text('${r.proName ?? ''} · ${timeAgo(l, r.createdAt)}',
                                  style: const TextStyle(color: BallalColors.muted, fontSize: 12)),
                            ]),
                          ),
                          StatusChip(status: r.status),
                        ]),
                      ),
                  ]);
                },
              ),
            SectionHeader(title: l.allProfessionals),
            if (_feedError != null && _feed.isEmpty)
              ErrorState(error: _feedError!, onRetry: () => _loadFeed(reset: true))
            else if (_feed.isEmpty && _feedLoading)
              const SizedBox(height: 120, child: LoadingView())
            else if (_feed.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.noProYet, textAlign: TextAlign.center, style: const TextStyle(color: BallalColors.muted)),
              ),
            for (var i = 0; i < _feed.length; i++) ...[
              FadeSlideIn(index: i % 10, child: ProListTile(pro: _feed[i])),
              // Publicité discrète : une annonce après chaque série de 10 professionnels.
              if ((i + 1) % 10 == 0 && _ads.isNotEmpty) AdCard(ad: _ads[((i + 1) ~/ 10 - 1) % _ads.length]),
            ],
            if (_feedHasMore && _feed.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: _feedLoading
                      ? const CircularProgressIndicator()
                      : OutlinedButton(onPressed: _loadFeed, child: Text(l.loadMore)),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  void _allCategories(List<Category> families) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final c in families)
            ListTile(
              leading: Icon(categoryIcon(c.icon), color: BallalColors.primary),
              title: Text(c.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                context.go('/search?category=${c.id}');
              },
            ),
        ]),
      ),
    );
  }
}

/// Bannière bleue avec l'homme « pouce levé » (maquette).
class _Banner extends StatelessWidget {
  const _Banner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FadeSlideIn(
      child: Container(
        height: 168,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: kBrandGradient,
          boxShadow: [BoxShadow(color: BallalColors.primary.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned(
            right: -30,
            bottom: -50,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          // Photo dans un cadre arrondi à bord blanc (fond studio clair, pas de détourage).
          Positioned(
            right: 14,
            top: 14,
            bottom: 14,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(24 * (1 - v), 0), child: child)),
              child: AspectRatio(
                aspectRatio: 0.82,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 3),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 8))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Image.asset('assets/people/business.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 0, 18),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.5,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.bannerTitle, style: displayStyle(19, color: Colors.white)),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: BallalColors.accent,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: onTap,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(l.bannerCta),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BallalCard(
      padding: const EdgeInsets.all(8),
      onTap: onTap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(color: BallalColors.accentSoft, shape: BoxShape.circle),
          child: Icon(icon, color: BallalColors.accent, size: 26),
        ),
        const SizedBox(height: 6),
        Text(label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ═════════════ Tableau de bord professionnel ═════════════
class ProDashboard extends StatefulWidget {
  const ProDashboard({super.key});
  static const route = '/pro-dashboard';

  @override
  State<ProDashboard> createState() => _ProDashboardState();
}

class _ProDashboardState extends State<ProDashboard> {
  late Future<(Map<String, int>, Map<String, dynamic>?, List<ServiceRequest>)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(Map<String, int>, Map<String, dynamic>?, List<ServiceRequest>)> _load() async {
    final stats = await ProRepo.instance.dashboardStats();
    final profile = await ProRepo.instance.myProfile();
    final reqs = await RequestRepo.instance.mine(asPro: true);
    return (stats, profile, reqs.take(5).toList());
  }

  Future<void> _setAvailability(String v) async {
    try {
      await ProRepo.instance.setAvailability(v);
      setState(() => _future = _load());
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.proSpace)),
      body: SafeArea(
        child: FutureBuilder(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) return ErrorState(error: snap.error!, onRetry: () => setState(() => _future = _load()));
            if (!snap.hasData) return const LoadingView();
            final (stats, profile, reqs) = snap.data!;
            final published = (profile?['is_published'] as bool?) ?? false;
            final availability = (profile?['availability'] as String?) ?? 'available';
            final rating = ((profile?['rating_avg'] as num?) ?? 0).toDouble();
            final ratingCount = ((profile?['rating_count'] as num?) ?? 0).toInt();
            return RefreshIndicator(
              onRefresh: () async => setState(() => _future = _load()),
              child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Text(l.helloName((profile?['display_name'] as String?) ?? ''),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ),
                if (!published)
                  BallalCard(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    onTap: () => context.push('/pro-edit'),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded, color: BallalColors.accent),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l.profileNotPublished)),
                      const Icon(Icons.chevron_right),
                    ]),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: DropdownButtonFormField<String>(
                    initialValue: availability,
                    decoration: InputDecoration(labelText: l.myAvailability),
                    items: [
                      for (final v in const ['available', 'busy', 'by_appointment', 'unavailable'])
                        DropdownMenuItem(value: v, child: AvailabilityTag(value: v)),
                    ],
                    onChanged: (v) {
                      if (v != null) _setAvailability(v);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.1,
                    children: [
                      _Stat(value: '${stats['new']}', label: l.statNew, color: BallalColors.accent),
                      _Stat(value: '${stats['active']}', label: l.statActive, color: BallalColors.primary),
                      _Stat(value: '${stats['done']}', label: l.statDone, color: BallalColors.success),
                      _Stat(value: '${stats['views']}', label: l.statViews, color: BallalColors.primaryDark),
                      _Stat(value: '${stats['favorites']}', label: l.statFavorites, color: BallalColors.danger),
                      _Stat(value: ratingCount == 0 ? '–' : formatRating(rating), label: l.statRating, color: BallalColors.star),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/pro-edit'),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(l.editProfile),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/my-services'),
                        icon: const Icon(Icons.design_services_outlined, size: 18),
                        label: Text(l.myServices),
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.verified_outlined,
                        label: (profile?['identity_verified'] as bool? ?? false) ? l.verifApproved : l.verifyMyProfile,
                        color: BallalColors.primary,
                        onTap: () => context.push('/verification'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.workspace_premium_rounded,
                        label: l.boostMyProfile,
                        color: BallalColors.accent,
                        onTap: () => context.push('/premium'),
                      ),
                    ),
                  ]),
                ),
                SectionHeader(title: l.receivedRequests, action: l.seeAll, onAction: () => context.push('/requests')),
                if (reqs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(l.noRequestsYetPro, style: const TextStyle(color: BallalColors.muted)),
                  ),
                for (final r in reqs)
                  BallalCard(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    onTap: () => context.push('/requests/${r.id}'),
                    child: Row(children: [
                      Avatar(name: r.clientName ?? '?', size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${r.clientName ?? ''} · ${timeAgo(l, r.createdAt)}',
                              style: const TextStyle(color: BallalColors.muted, fontSize: 12)),
                        ]),
                      ),
                      StatusChip(status: r.status),
                    ]),
                  ),
              ]),
            );
          },
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return BallalCard(
      padding: const EdgeInsets.all(10),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 11, color: BallalColors.muted)),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BallalCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, maxLines: 2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
      ]),
    );
  }
}
