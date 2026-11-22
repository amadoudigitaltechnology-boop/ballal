import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../core/unread.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _future = NotificationRepo.instance.list();

  Future<void> _reload() async {
    setState(() => _future = NotificationRepo.instance.list());
    await _future;
  }

  Future<void> _markAll() async {
    try {
      await NotificationRepo.instance.markAllRead();
      await Unread.instance.refresh();
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      NotificationRepo.instance.markRead(n.id).then((_) => Unread.instance.refresh()).ignore();
    }
    final id = n.entityId;
    if (id == null) return;
    switch (n.entityType) {
      case 'service_request':
        await context.push('/requests/$id');
      case 'conversation':
        await context.push('/chat/$id');
      case 'review':
        final me = currentUserId;
        if (me != null) await context.push('/pro/$me');
    }
    _reload();
  }

  IconData _icon(String type) => switch (type) {
        'new_message' => Icons.chat_bubble_rounded,
        'new_request' => Icons.assignment_rounded,
        'request_update' => Icons.check_circle_rounded,
        'new_review' || 'review_reply' => Icons.star_rounded,
        'security' => Icons.shield_rounded,
        _ => Icons.notifications_rounded,
      };

  Color _color(String type) => switch (type) {
        'new_message' => BallalColors.primary,
        'new_request' => BallalColors.accent,
        'request_update' => BallalColors.success,
        'new_review' || 'review_reply' => BallalColors.star,
        'security' => BallalColors.danger,
        _ => BallalColors.muted,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.notifications),
          actions: [IconButton(tooltip: l.markAllRead, onPressed: _markAll, icon: const Icon(Icons.done_all_rounded))],
          bottom: TabBar(tabs: [Tab(text: l.tabAll), Tab(text: l.navMessages), Tab(text: l.tabActivity)]),
        ),
        body: FutureBuilder<List<AppNotification>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) return ErrorState(error: snap.error!, onRetry: _reload);
            if (!snap.hasData) return const LoadingView();
            final all = snap.data!;
            Widget list(List<AppNotification> items) {
              if (items.isEmpty) return EmptyState(icon: Icons.notifications_none_rounded, title: l.noNotifications);
              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(indent: 72),
                  itemBuilder: (_, i) {
                    final n = items[i];
                    final c = _color(n.type);
                    return ListTile(
                      tileColor: n.isRead ? null : BallalColors.primarySoft.withValues(alpha: 0.5),
                      leading: CircleAvatar(backgroundColor: c.withValues(alpha: 0.15), child: Icon(_icon(n.type), color: c)),
                      title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700)),
                      subtitle: Text([if (n.body != null) n.body!, timeAgo(l, n.createdAt)].join('\n')),
                      isThreeLine: n.body != null,
                      onTap: () => _open(n),
                    );
                  },
                ),
              );
            }

            return TabBarView(children: [
              list(all),
              list(all.where((n) => n.type == 'new_message').toList()),
              list(all.where((n) => n.type != 'new_message').toList()),
            ]);
          },
        ),
      ),
    );
  }
}
