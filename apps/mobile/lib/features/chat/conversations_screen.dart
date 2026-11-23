import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../core/unread.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  Future<List<ConversationSummary>>? _future;
  bool _unreadOnly = false;
  int _unreadTotal = 0;
  String _filter = '';
  int _lastUnread = -1;

  @override
  void initState() {
    super.initState();
    Unread.instance.addListener(_onUnread);
    _reload();
  }

  @override
  void dispose() {
    Unread.instance.removeListener(_onUnread);
    super.dispose();
  }

  void _onUnread() {
    // Nouveau message reçu ailleurs : on rafraîchit la liste.
    if (Unread.instance.messages != _lastUnread) {
      _lastUnread = Unread.instance.messages;
      _reload();
    }
  }

  void _reload() {
    if (!Session.instance.isSignedIn) return;
    setState(() => _future = ChatRepo.instance.list());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (!Session.instance.isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(l.navMessages)),
        body: EmptyState(
          icon: Icons.forum_outlined,
          title: l.loginToChat,
          action: l.login,
          onAction: () => context.push('/login'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.navMessages), centerTitle: false, actions: [IconButton(icon: const Icon(Icons.edit_square), tooltip: l.navSearch, onPressed: () => context.go('/search'))]),
      body: Column(children: [
        // Filtres Toutes / Non lues (maquette)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(children: [
            for (final unreadOnly in [false, true])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(unreadOnly ? '${l.unreadTab}${_unreadTotal > 0 ? ' ($_unreadTotal)' : ''}' : l.allTab),
                  selected: _unreadOnly == unreadOnly,
                  showCheckmark: false,
                  selectedColor: BallalColors.primarySoft,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _unreadOnly == unreadOnly ? BallalColors.primary : BallalColors.muted,
                  ),
                  onSelected: (_) => setState(() => _unreadOnly = unreadOnly),
                ),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _filter = v.toLowerCase().trim()),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.searchConversation),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ConversationSummary>>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) return ErrorState(error: snap.error!, onRetry: _reload);
              if (!snap.hasData) return const LoadingView();
              final all = snap.data!;
              final total = all.fold<int>(0, (a, c) => a + (c.unreadCount > 0 ? 1 : 0));
              if (total != _unreadTotal) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _unreadTotal = total);
                });
              }
              final items = all
                  .where((c) => _filter.isEmpty || c.otherName.toLowerCase().contains(_filter))
                  .where((c) => !_unreadOnly || c.unreadCount > 0)
                  .toList();
              if (items.isEmpty) {
                return EmptyState(icon: Icons.forum_outlined, title: l.noConversations, message: l.noConversationsHint);
              }
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(indent: 80),
                  itemBuilder: (_, i) {
                    final c = items[i];
                    final unread = c.unreadCount > 0;
                    return FadeSlideIn(index: i, child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Avatar(
                        url: c.otherAvatar == null ? null : publicUrl(c.otherIsPro ? 'pro-media' : 'avatars', c.otherAvatar!),
                        name: c.otherName,
                        size: 52,
                      ),
                      title: Text(c.otherName,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
                      subtitle: Text(c.lastMessagePreview ?? l.newConversation,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: unread ? BallalColors.text : BallalColors.muted)),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        if (c.lastMessageAt != null)
                          Text(timeAgo(l, c.lastMessageAt!), style: const TextStyle(fontSize: 12, color: BallalColors.muted)),
                        const SizedBox(height: 4),
                        if (unread)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: BallalColors.primary, borderRadius: BorderRadius.circular(10)),
                            child: Text('${c.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                      ]),
                      onTap: () async {
                        await context.push('/chat/${c.id}');
                        _reload();
                        Unread.instance.refresh();
                      },
                    ));
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
