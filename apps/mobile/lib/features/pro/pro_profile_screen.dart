import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatters.dart';
import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';
import '../search/search_screen.dart';

class ProProfileScreen extends StatefulWidget {
  const ProProfileScreen({super.key, required this.proId});
  final String proId;

  @override
  State<ProProfileScreen> createState() => _ProProfileScreenState();
}

class _ProProfileScreenState extends State<ProProfileScreen> {
  late Future<ProDetail?> _detail;
  late Future<List<ProService>> _services;
  late Future<List<Review>> _reviews;
  late Future<List<String>> _portfolio;
  bool _contactBusy = false;

  bool get _isMe => currentUserId == widget.proId;

  @override
  void initState() {
    super.initState();
    _load();
    ProRepo.instance.recordView(widget.proId);
  }

  void _load() {
    _detail = ProRepo.instance.detail(widget.proId);
    _services = ProRepo.instance.services(widget.proId);
    _reviews = ProRepo.instance.reviews(widget.proId);
    _portfolio = ProRepo.instance.portfolio(widget.proId);
  }

  void _request(ProDetail pro, {ProService? service}) {
    if (!requireAuth(context)) return;
    if (!Session.instance.isClient) {
      _askActivateClient();
      return;
    }
    ProRepo.instance.logRecoEvent(pro.id, 'request');
    context.push('/request/new', extra: {'proId': pro.id, 'proName': pro.displayName, 'service': service});
  }

  Future<void> _askActivateClient() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.activateClientTitle),
        content: Text(l.activateClientText),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.activate)),
        ],
      ),
    );
    if (ok == true) {
      try {
        await Session.instance.activateRole('client');
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
  }

  Future<void> _message(ProDetail pro) async {
    if (!requireAuth(context) || _contactBusy) return;
    setState(() => _contactBusy = true);
    try {
      final id = await ChatRepo.instance.start(professionalId: pro.id);
      ProRepo.instance.logRecoEvent(pro.id, 'contact');
      if (mounted) context.push('/chat/$id');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _contactBusy = false);
    }
  }

  Future<void> _call(ProDetail pro, {bool whatsapp = false}) async {
    if (!requireAuth(context) || _contactBusy) return;
    final l = context.l10n;
    setState(() => _contactBusy = true);
    try {
      final c = await ProRepo.instance.contact(pro.id);
      final number = whatsapp ? c.whatsapp : c.phone;
      if (number == null) {
        if (mounted) showInfo(context, l.contactHidden);
        return;
      }
      ProRepo.instance.logRecoEvent(pro.id, 'contact');
      final uri = whatsapp ? Uri.parse('https://wa.me/${number.replaceAll('+', '')}') : Uri.parse('tel:$number');
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) showInfo(context, number);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _contactBusy = false);
    }
  }

  Future<void> _report(ProDetail pro) async {
    if (!requireAuth(context)) return;
    final sent = await showReportSheet(context, targetType: 'professional', targetId: pro.id);
    if (sent == true && mounted) showInfo(context, context.l10n.reportSent);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FutureBuilder<ProDetail?>(
      future: _detail,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(appBar: AppBar(), body: ErrorState(error: snap.error!, onRetry: () => setState(_load)));
        }
        if (snap.connectionState != ConnectionState.done) return Scaffold(appBar: AppBar(), body: const LoadingView());
        final pro = snap.data;
        if (pro == null) {
          return Scaffold(appBar: AppBar(), body: EmptyState(icon: Icons.person_off_outlined, title: l.proNotFound));
        }
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: BallalColors.bg,
            body: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 200,
                  backgroundColor: BallalColors.primaryDark,
                  foregroundColor: Colors.white,
                  actions: [
                    if (!_isMe) FavoriteButton(proId: pro.id),
                    if (!_isMe)
                      PopupMenuButton<String>(
                        onSelected: (_) => _report(pro),
                        itemBuilder: (_) => [PopupMenuItem(value: 'report', child: Text(l.report))],
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: pro.coverPath != null
                        ? CachedNetworkImage(imageUrl: proImageUrl(pro.coverPath)!, fit: BoxFit.cover)
                        : const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [BallalColors.primary, BallalColors.primaryDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                  ),
                ),
                SliverToBoxAdapter(child: _Header(pro: pro)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabsDelegate(TabBar(
                    labelColor: BallalColors.primary,
                    unselectedLabelColor: BallalColors.muted,
                    indicatorColor: BallalColors.primary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                    tabs: [Tab(text: l.tabAbout), Tab(text: l.tabReviews), Tab(text: l.tabServices)],
                  )),
                ),
              ],
              body: TabBarView(children: [
                _AboutTab(pro: pro, portfolio: _portfolio),
                _ReviewsTab(reviews: _reviews, pro: pro),
                _ServicesTab(services: _services, onRequest: _isMe ? null : (s) => _request(pro, service: s)),
              ]),
            ),
            bottomNavigationBar: SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                color: Colors.white,
                child: _isMe
                    ? FilledButton.icon(
                        onPressed: () => context.push('/pro-edit'),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(l.editProfile),
                      )
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: BallalColors.accent),
                          onPressed: () => _request(pro),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(l.sendRequest),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _contactBusy ? null : () => _call(pro),
                              icon: const Icon(Icons.call_outlined, size: 18),
                              label: Text(l.call),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _contactBusy ? null : () => _call(pro, whatsapp: true),
                              icon: const Icon(Icons.chat_outlined, size: 18),
                              label: const Text('WhatsApp'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _contactBusy ? null : () => _message(pro),
                              icon: const Icon(Icons.forum_outlined, size: 18),
                              label: Text(l.message),
                            ),
                          ),
                        ]),
                      ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.pro});
  final ProDetail pro;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BallalCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        Avatar(url: proImageUrl(pro.logoPath), name: pro.displayName, size: 64),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(pro.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 4),
              VerifiedBadge(identity: pro.identityVerified, company: pro.companyVerified),
            ]),
            Text(pro.headline, style: const TextStyle(color: BallalColors.muted)),
            const SizedBox(height: 6),
            RatingRow(rating: pro.ratingAvg, count: pro.ratingCount),
            const SizedBox(height: 6),
            Wrap(spacing: 12, children: [
              AvailabilityTag(value: pro.availability),
              Text(pro.proType == 'company' ? l.typeCompany : l.typeIndependent,
                  style: const TextStyle(fontSize: 12, color: BallalColors.muted)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  _TabsDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: BallalColors.bg, child: tabBar);

  @override
  bool shouldRebuild(covariant _TabsDelegate oldDelegate) => false;
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.pro, required this.portfolio});
  final ProDetail pro;
  final Future<List<String>> portfolio;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final days = [l.dayMon, l.dayTue, l.dayWed, l.dayThu, l.dayFri, l.daySat, l.daySun];
    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 6),
            child,
          ]),
        );
    return ListView(padding: const EdgeInsets.all(20), children: [
      if (pro.description.isNotEmpty) section(l.presentation, Text(pro.description, style: const TextStyle(height: 1.45))),
      section(
        l.verifications,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _check(true, l.verifPhone),
          _check(pro.identityVerified, l.verifIdentity),
          if (pro.proType == 'company') _check(pro.companyVerified, l.verifCompany),
          const SizedBox(height: 4),
          Text(l.verifDisclaimer, style: const TextStyle(fontSize: 12, color: BallalColors.muted)),
        ]),
      ),
      if (pro.experienceYears != null) section(l.experience, Text(l.yearsExperience(pro.experienceYears.toString()))),
      if (pro.skills.isNotEmpty)
        section(l.skills, Wrap(spacing: 6, runSpacing: 6, children: [for (final s in pro.skills) Chip(label: Text(s))])),
      if (pro.locationName != null || pro.areas.isNotEmpty)
        section(l.serviceZones, Text({if (pro.locationName != null) pro.locationName!, ...pro.areas}.join(' · '))),
      if (pro.priceHint != null && pro.priceHint!.isNotEmpty)
        section(l.indicativePrices, Text(pro.priceHint!)),
      if (pro.hours.isNotEmpty)
        section(
          l.openingHours,
          Column(children: [
            for (final h in pro.hours)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  SizedBox(width: 100, child: Text(days[h.weekday.clamp(0, 6)])),
                  Text('${h.opens} – ${h.closes}'),
                ]),
              ),
          ]),
        ),
      if (pro.languages.isNotEmpty) section(l.languages, Text(pro.languages.map(_langName).join(', '))),
      FutureBuilder<List<String>>(
        future: portfolio,
        builder: (context, snap) {
          final items = snap.data ?? const <String>[];
          if (items.isEmpty) return const SizedBox.shrink();
          return section(
            l.portfolio,
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (final p in items)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(imageUrl: proImageUrl(p)!, fit: BoxFit.cover, memCacheWidth: 300),
                  ),
              ],
            ),
          );
        },
      ),
    ]);
  }

  Widget _check(bool ok, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 18, color: ok ? BallalColors.success : BallalColors.muted),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: ok ? BallalColors.text : BallalColors.muted)),
        ]),
      );

  String _langName(String code) => switch (code) {
        'fr' => 'Français',
        'ff' => 'Pular',
        'sus' => 'Soussou',
        'man' => 'Malinké',
        'en' => 'English',
        _ => code,
      };
}

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({required this.reviews, required this.pro});
  final Future<List<Review>> reviews;
  final ProDetail pro;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FutureBuilder<List<Review>>(
      future: reviews,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text(friendlyError(context, snap.error!)));
        if (!snap.hasData) return const LoadingView();
        final items = snap.data!;
        if (items.isEmpty) {
          return EmptyState(icon: Icons.star_outline_rounded, title: l.noReviewsYet, message: l.reviewsExplain);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            if (i == 0) {
              return Row(children: [
                Text(formatRating(pro.ratingAvg), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Stars(rating: pro.ratingAvg.round()),
                  Text(l.reviewsCount(pro.ratingCount.toString()), style: const TextStyle(color: BallalColors.muted)),
                ]),
              ]);
            }
            final r = items[i - 1];
            return BallalCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _Stars(rating: r.rating),
                  const Spacer(),
                  Text(formatDate(r.createdAt), style: const TextStyle(fontSize: 12, color: BallalColors.muted)),
                ]),
                const SizedBox(height: 4),
                Text(l.verifiedClient, style: const TextStyle(fontSize: 12, color: BallalColors.success, fontWeight: FontWeight.w600)),
                if (r.comment != null) ...[const SizedBox(height: 6), Text(r.comment!)],
                if (r.reply != null)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: BallalColors.bg, borderRadius: BorderRadius.circular(10)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.proReply, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(r.reply!),
                    ]),
                  ),
              ]),
            );
          },
        );
      },
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});
  final int rating;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 18, color: BallalColors.star),
      ]);
}

class _ServicesTab extends StatelessWidget {
  const _ServicesTab({required this.services, required this.onRequest});
  final Future<List<ProService>> services;
  final void Function(ProService)? onRequest;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FutureBuilder<List<ProService>>(
      future: services,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text(friendlyError(context, snap.error!)));
        if (!snap.hasData) return const LoadingView();
        final items = snap.data!;
        if (items.isEmpty) return EmptyState(icon: Icons.design_services_outlined, title: l.noServices);
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final s = items[i];
            final price = formatPriceRange(s.priceMin, s.priceMax, s.priceUnit);
            return BallalCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.check_circle_rounded, color: BallalColors.success, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                ]),
                if (s.description.isNotEmpty) ...[const SizedBox(height: 6), Text(s.description)],
                if (price.isNotEmpty || s.durationText != null) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 12, children: [
                    if (price.isNotEmpty)
                      Text(l.fromPrice(price), style: const TextStyle(fontWeight: FontWeight.w600, color: BallalColors.primary)),
                    if (s.durationText != null) Text('⏱ ${s.durationText}', style: const TextStyle(color: BallalColors.muted)),
                  ]),
                  Text(l.indicativeOnly, style: const TextStyle(fontSize: 11, color: BallalColors.muted)),
                ],
                if (onRequest != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: () => onRequest!(s), child: Text(l.requestThisService)),
                  ),
              ]),
            );
          },
        );
      },
    );
  }
}

/// Feuille de signalement commune (profil, message, avis…).
Future<bool?> showReportSheet(BuildContext context,
    {required String targetType, required String targetId, List<String> messageIds = const []}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReportSheet(targetType: targetType, targetId: targetId, messageIds: messageIds),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.targetType, required this.targetId, required this.messageIds});
  final String targetType;
  final String targetId;
  final List<String> messageIds;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;
  final _details = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reason == null) return;
    setState(() => _busy = true);
    try {
      await ReportRepo.report(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: _reason!,
        description: _details.text.trim().isEmpty ? null : _details.text.trim(),
        messageIds: widget.messageIds,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reasons = {
      'spam': l.reasonSpam,
      'fraud': l.reasonFraud,
      'harassment': l.reasonHarassment,
      'inappropriate': l.reasonInappropriate,
      'fake_profile': l.reasonFakeProfile,
      'other': l.reasonOther,
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.report, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        if (widget.messageIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l.reportMessagesShared(widget.messageIds.length.toString()),
                style: const TextStyle(color: BallalColors.muted, fontSize: 13)),
          ),
        const SizedBox(height: 8),
        for (final e in reasons.entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _reason == e.key ? Icons.radio_button_checked : Icons.radio_button_off,
              color: _reason == e.key ? BallalColors.primary : BallalColors.muted,
            ),
            title: Text(e.value),
            selected: _reason == e.key,
            onTap: () => setState(() => _reason = e.key),
          ),
        TextField(controller: _details, maxLines: 3, maxLength: 1000, decoration: InputDecoration(hintText: l.reportDetailsHint)),
        const SizedBox(height: 8),
        FilledButton(onPressed: _reason == null || _busy ? null : _send, child: Text(l.send)),
      ]),
    );
  }
}
