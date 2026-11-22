import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/formatters.dart';
import '../core/session.dart';
import '../core/supa.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import '../l10n/gen/app_localizations.dart';

/// Logo texte BALLAL (remplaçable par le fichier officiel dans assets/).
class BallalLogo extends StatelessWidget {
  const BallalLogo({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => const LinearGradient(
        colors: [BallalColors.primary, BallalColors.primaryDark, BallalColors.accent],
        stops: [0, 0.6, 1],
      ).createShader(r),
      child: Text(
        'BALLAL',
        semanticsLabel: 'BALLAL',
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: 1.2,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Exige une session ; sinon ouvre la connexion. Renvoie true si connecté.
bool requireAuth(BuildContext context) {
  if (Session.instance.isSignedIn) return true;
  context.push('/login');
  return false;
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, this.url, required this.name, this.size = 48, this.radius});
  final String? url;
  final String name;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: BallalColors.primarySoft,
      child: Text(initials,
          style: TextStyle(color: BallalColors.primary, fontWeight: FontWeight.w700, fontSize: size * 0.36)),
    );
    final r = BorderRadius.circular(radius ?? size / 2);
    if (url == null || url!.isEmpty) return ClipRRect(borderRadius: r, child: fallback);
    return ClipRRect(
      borderRadius: r,
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: (size * 3).round(),
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

String? proImageUrl(String? path) => path == null ? null : publicUrl('pro-media', path);

class RatingRow extends StatelessWidget {
  const RatingRow({super.key, required this.rating, required this.count, this.size = 14});
  final double rating;
  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (count == 0) {
      return Text(l.noReviewsYet, style: TextStyle(fontSize: size - 1, color: BallalColors.muted));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.star_rounded, size: size + 3, color: BallalColors.star),
      const SizedBox(width: 2),
      Text(formatRating(rating), style: TextStyle(fontSize: size, fontWeight: FontWeight.w700)),
      const SizedBox(width: 4),
      Text(l.reviewsCount(count.toString()), style: TextStyle(fontSize: size - 1, color: BallalColors.muted)),
    ]);
  }
}

/// Badge qui dit précisément ce qui a été vérifié (cahier §9).
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, required this.identity, required this.company, this.size = 18});
  final bool identity;
  final bool company;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!identity && !company) return const SizedBox.shrink();
    final l = context.l10n;
    return Tooltip(
      message: company ? l.badgeCompanyVerified : l.badgeIdentityVerified,
      child: Icon(Icons.verified_rounded, size: size, color: BallalColors.primary, semanticLabel: l.badgeIdentityVerified),
    );
  }
}

String availabilityLabel(AppLocalizations l, String a) => switch (a) {
      'available' => l.availAvailable,
      'busy' => l.availBusy,
      'unavailable' => l.availUnavailable,
      'by_appointment' => l.availByAppointment,
      _ => a,
    };

Color availabilityColor(String a) => switch (a) {
      'available' => BallalColors.success,
      'busy' => BallalColors.warning,
      'by_appointment' => BallalColors.primary,
      _ => BallalColors.muted,
    };

class AvailabilityTag extends StatelessWidget {
  const AvailabilityTag({super.key, required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = availabilityColor(value);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(availabilityLabel(context.l10n, value), style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
    ]);
  }
}

String requestStatusLabel(AppLocalizations l, String s) => switch (s) {
      'pending' => l.statusPending,
      'needs_info' => l.statusNeedsInfo,
      'in_discussion' => l.statusInDiscussion,
      'accepted' => l.statusAccepted,
      'declined' => l.statusDeclined,
      'cancelled' => l.statusCancelled,
      'completed' => l.statusCompleted,
      _ => s,
    };

Color requestStatusColor(String s) => switch (s) {
      'pending' => BallalColors.warning,
      'needs_info' => BallalColors.accent,
      'in_discussion' => BallalColors.primary,
      'accepted' => BallalColors.success,
      'completed' => BallalColors.success,
      _ => BallalColors.muted,
    };

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = requestStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(requestStatusLabel(context.l10n, status),
          style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action, this.onAction});
  final IconData icon;
  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: BallalColors.primarySoft, shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: BallalColors.primary),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: const TextStyle(color: BallalColors.muted)),
          ],
          if (action != null && onAction != null) ...[
            const SizedBox(height: 20),
            SizedBox(width: 220, child: FilledButton(onPressed: onAction, child: Text(action!))),
          ],
        ]),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.wifi_off_rounded,
        title: friendlyError(context, error),
        action: context.l10n.retry,
        onAction: onRetry,
      );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

IconData categoryIcon(String? key) => switch (key) {
      'construction' => Icons.construction_rounded,
      'home' => Icons.home_repair_service_rounded,
      'computer' => Icons.computer_rounded,
      'local_shipping' => Icons.local_shipping_rounded,
      'face' => Icons.face_retouching_natural_rounded,
      'school' => Icons.school_rounded,
      'palette' => Icons.palette_rounded,
      'business_center' => Icons.business_center_rounded,
      'celebration' => Icons.celebration_rounded,
      _ => Icons.handyman_rounded,
    };

/// Ligne de résultat (écran Recherche / Favoris), fidèle à la maquette.
class ProListTile extends StatelessWidget {
  const ProListTile({super.key, required this.pro, this.onTap, this.trailing});
  final ProCard pro;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return BallalCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      onTap: onTap ?? () => context.push('/pro/${pro.id}'),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Avatar(url: proImageUrl(pro.logoPath), name: pro.displayName, size: 64, radius: 14),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(pro.displayName,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              const SizedBox(width: 4),
              VerifiedBadge(identity: pro.identityVerified, company: pro.companyVerified, size: 16),
            ]),
            const SizedBox(height: 2),
            Text(pro.headline, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: BallalColors.muted, fontSize: 13)),
            const SizedBox(height: 6),
            RatingRow(rating: pro.ratingAvg, count: pro.ratingCount, size: 13),
            const SizedBox(height: 6),
            Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              AvailabilityTag(value: pro.availability),
              if (pro.locationName != null)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.place_outlined, size: 14, color: BallalColors.muted),
                  Text(pro.locationName!, style: const TextStyle(fontSize: 12, color: BallalColors.muted)),
                ]),
            ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          trailing ?? const SizedBox(height: 24),
          if (pro.distanceKm != null) ...[
            const SizedBox(height: 18),
            Text(formatKm(pro.distanceKm!), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ]),
      ]),
    );
  }
}

/// Carte compacte « Recommandés pour vous » avec explication.
class ProRecoCard extends StatelessWidget {
  const ProRecoCard({super.key, required this.pro, required this.onTap});
  final ProCard pro;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: BallalCard(
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Avatar(url: proImageUrl(pro.logoPath), name: pro.displayName, size: 44, radius: 12),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(pro.displayName,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  VerifiedBadge(identity: pro.identityVerified, company: pro.companyVerified, size: 14),
                ]),
                Text(pro.headline, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: BallalColors.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          RatingRow(rating: pro.ratingAvg, count: pro.ratingCount, size: 12),
          const Spacer(),
          if (pro.reasons.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: BallalColors.primarySoft, borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.auto_awesome_rounded, size: 12, color: BallalColors.primary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(pro.reasons.first, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: BallalColors.primary, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// Sélecteur de zone hiérarchique (ville → commune → quartier), sans GPS.
Future<Place?> pickPlace(BuildContext context, {String? title}) {
  return showModalBottomSheet<Place>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PlacePicker(title: title),
  );
}

class _PlacePicker extends StatefulWidget {
  const _PlacePicker({this.title});
  final String? title;

  @override
  State<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<_PlacePicker> {
  final List<Place> _trail = [];
  late Future<List<Place>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Place>> _load() async {
    final repo = CatalogRepo.instance;
    if (_trail.isEmpty) {
      // On commence directement par les villes de Guinée (pays > région > ville).
      final all = await repo.places();
      return all.where((p) => p.level == 'city').toList();
    }
    return repo.children(_trail.last.id);
  }

  void _open(Place p) {
    setState(() {
      _trail.add(p);
      _future = _load();
    });
  }

  void _back() {
    setState(() {
      _trail.removeLast();
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(children: [
        ListTile(
          leading: _trail.isEmpty ? null : IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
          title: Text(_trail.isEmpty ? (widget.title ?? l.chooseZone) : _trail.last.name,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        if (_trail.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.check_circle_outline, color: BallalColors.primary),
            title: Text(l.allOfZone(_trail.last.name)),
            onTap: () => Navigator.pop(context, _trail.last),
          ),
        const Divider(),
        Expanded(
          child: FutureBuilder<List<Place>>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) return ErrorState(error: snap.error!, onRetry: () => setState(() => _future = _load()));
              if (!snap.hasData) return const LoadingView();
              final items = snap.data!;
              if (items.isEmpty) return Center(child: Text(l.noSubZones));
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final p = items[i];
                  final leaf = p.level == 'quartier';
                  return ListTile(
                    title: Text(p.name),
                    trailing: leaf ? null : const Icon(Icons.chevron_right),
                    onTap: () => leaf ? Navigator.pop(context, p) : _open(p),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
