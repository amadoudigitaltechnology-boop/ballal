import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' hide Path;
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

/// Carte « Proche de vous » : épingles des pros (centre de leur quartier, jamais l'adresse exacte).
class ProMap extends StatefulWidget {
  const ProMap({super.key, required this.pros, this.userLat, this.userLng, this.height = 300});
  final List<ProCard> pros;
  final double? userLat;
  final double? userLng;
  final double height;

  @override
  State<ProMap> createState() => _ProMapState();
}

class _ProMapState extends State<ProMap> {
  static const _conakry = LatLng(9.6412, -13.5784);
  final _map = MapController();
  String? _selected;

  LatLng get _center {
    if (widget.userLat != null && widget.userLng != null) return LatLng(widget.userLat!, widget.userLng!);
    final first = widget.pros.where((p) => p.lat != null).firstOrNull;
    return first == null ? _conakry : LatLng(first.lat!, first.lng!);
  }

  /// Plusieurs pros d'un même quartier : on les écarte légèrement pour qu'ils restent touchables.
  List<(ProCard, LatLng)> _positions() {
    final seen = <String, int>{};
    final out = <(ProCard, LatLng)>[];
    for (final p in widget.pros.where((p) => p.lat != null && p.lng != null)) {
      final key = '${p.lat!.toStringAsFixed(4)},${p.lng!.toStringAsFixed(4)}';
      final n = seen[key] = (seen[key] ?? -1) + 1;
      final angle = n * 2.4;
      final r = n == 0 ? 0.0 : 0.0012 * (1 + n / 6);
      out.add((p, LatLng(p.lat! + r * _sin(angle), p.lng! + r * _cos(angle))));
    }
    return out;
  }

  static double _sin(double x) => math.sin(x);
  static double _cos(double x) => math.cos(x);

  @override
  Widget build(BuildContext context) {
    final positions = _positions();
    final hasUser = widget.userLat != null && widget.userLng != null;
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadius),
        child: Stack(children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: hasUser ? 13.5 : 12,
              minZoom: 6,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onTap: (_, __) => setState(() => _selected = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.amadoutechnology.ballal',
                maxNativeZoom: 19,
              ),
              if (hasUser)
                CircleLayer(circles: [
                  CircleMarker(
                    point: LatLng(widget.userLat!, widget.userLng!),
                    radius: 600,
                    useRadiusInMeter: true,
                    color: BallalColors.primary.withValues(alpha: 0.12),
                    borderColor: BallalColors.primary.withValues(alpha: 0.3),
                    borderStrokeWidth: 1,
                  ),
                ]),
              MarkerLayer(markers: [
                if (hasUser)
                  Marker(
                    point: LatLng(widget.userLat!, widget.userLng!),
                    width: 26,
                    height: 26,
                    child: Container(
                      decoration: BoxDecoration(
                        color: BallalColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [BoxShadow(color: BallalColors.primary.withValues(alpha: 0.4), blurRadius: 10)],
                      ),
                    ),
                  ),
                for (final (pro, pos) in positions)
                  Marker(
                    point: pos,
                    width: _selected == pro.id ? 64 : 48,
                    height: _selected == pro.id ? 76 : 60,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selected = pro.id);
                        _map.move(pos, _map.camera.zoom);
                      },
                      child: _Pin(pro: pro, selected: _selected == pro.id),
                    ),
                  ),
              ]),
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [TextSourceAttribution('© OpenStreetMap')],
              ),
            ],
          ),
          Positioned(
            right: 10,
            top: 10,
            child: Column(children: [
              _MapButton(icon: Icons.add, onTap: () => _map.move(_map.camera.center, _map.camera.zoom + 1)),
              const SizedBox(height: 6),
              _MapButton(icon: Icons.remove, onTap: () => _map.move(_map.camera.center, _map.camera.zoom - 1)),
              const SizedBox(height: 6),
              _MapButton(icon: Icons.my_location_rounded, onTap: () => _map.move(_center, hasUser ? 13.5 : 12)),
            ]),
          ),
          if (_selected != null)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Builder(builder: (context) {
                final pro = widget.pros.firstWhere((p) => p.id == _selected);
                return FadeSlideIn(
                  child: BallalCard(
                    padding: const EdgeInsets.all(10),
                    onTap: () => context.push('/pro/${pro.id}'),
                    child: Row(children: [
                      ProPhoto(path: pro.logoPath, name: pro.displayName, width: 52, height: 52, radius: 12),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(pro.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(pro.headline, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: BallalColors.muted)),
                          RatingRow(rating: pro.ratingAvg, count: pro.ratingCount, size: 12),
                        ]),
                      ),
                      const Icon(Icons.chevron_right),
                    ]),
                  ),
                );
              }),
            ),
        ]),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.pro, required this.selected});
  final ProCard pro;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = pro.isFeatured ? BallalColors.accent : BallalColors.primary;
    return AnimatedScale(
      scale: selected ? 1.1 : 1,
      duration: const Duration(milliseconds: 180),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: ProPhoto(path: pro.logoPath, name: pro.displayName, width: selected ? 52 : 38, height: selected ? 52 : 38, radius: 40),
        ),
        CustomPaint(size: const Size(12, 8), painter: _Tail(color)),
      ]),
    );
  }
}

class _Tail extends CustomPainter {
  _Tail(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _Tail old) => old.color != color;
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, size: 20, color: BallalColors.primaryDark)),
      ),
    );
  }
}
