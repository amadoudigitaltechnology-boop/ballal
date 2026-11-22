import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  late Future<List<ServiceRequest>> _future;
  bool get _asPro => Session.instance.isProMode;

  @override
  void initState() {
    super.initState();
    _future = RequestRepo.instance.mine(asPro: _asPro);
  }

  Future<void> _reload() async {
    setState(() => _future = RequestRepo.instance.mine(asPro: _asPro));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    const openStatuses = {'pending', 'needs_info', 'in_discussion', 'accepted'};
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_asPro ? l.receivedRequests : l.myRequests),
          bottom: TabBar(tabs: [Tab(text: l.tabOngoing), Tab(text: l.tabClosed)]),
        ),
        body: FutureBuilder<List<ServiceRequest>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) return ErrorState(error: snap.error!, onRetry: _reload);
            if (!snap.hasData) return const LoadingView();
            final all = snap.data!;
            final open = all.where((r) => openStatuses.contains(r.status)).toList();
            final closed = all.where((r) => !openStatuses.contains(r.status)).toList();
            Widget list(List<ServiceRequest> items) {
              if (items.isEmpty) {
                return EmptyState(
                  icon: Icons.assignment_outlined,
                  title: _asPro ? l.noRequestsYetPro : l.noRequestsYet,
                  action: _asPro ? null : l.findPro,
                  onAction: _asPro ? null : () => context.go('/search'),
                );
              }
              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final r = items[i];
                    final who = _asPro ? (r.clientName ?? '') : (r.proName ?? '');
                    return BallalCard(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                      onTap: () async {
                        await context.push('/requests/${r.id}');
                        _reload();
                      },
                      child: Row(children: [
                        Avatar(name: who, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('$who · ${timeAgo(l, r.createdAt)}',
                                style: const TextStyle(color: BallalColors.muted, fontSize: 12)),
                          ]),
                        ),
                        StatusChip(status: r.status),
                      ]),
                    );
                  },
                ),
              );
            }

            return TabBarView(children: [list(open), list(closed)]);
          },
        ),
      ),
    );
  }
}
