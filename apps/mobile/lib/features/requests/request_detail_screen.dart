import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';

class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.requestId});
  final String requestId;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  late Future<(ServiceRequest?, List<StatusChange>, List<String>)> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(ServiceRequest?, List<StatusChange>, List<String>)> _load() async {
    final r = await RequestRepo.instance.get(widget.requestId);
    if (r == null) return (null, <StatusChange>[], <String>[]);
    final h = await RequestRepo.instance.history(r.id);
    final a = await RequestRepo.instance.attachmentUrls(r.id);
    return (r, h, a);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _setStatus(ServiceRequest r, String status, {bool askNote = false, bool confirm = false}) async {
    final l = context.l10n;
    String? note;
    if (askNote) {
      note = await _askNote(status == 'needs_info' ? l.whatInfoNeeded : l.optionalMessage);
      if (note == null) return;
    } else if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.confirmAction),
          content: Text(requestStatusLabel(l, status)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.confirm)),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      await RequestRepo.instance.setStatus(r.id, status, note: note);
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askNote(String label) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(controller: ctrl, maxLines: 3, maxLength: 500, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(context.l10n.send)),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  Future<void> _openChat(ServiceRequest r) async {
    setState(() => _busy = true);
    try {
      final id = await ChatRepo.instance.start(requestId: r.id);
      if (mounted) context.push('/chat/$id');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(ServiceRequest r) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReviewSheet(request: r),
    );
    if (done == true) {
      _reload();
      if (mounted) showInfo(context, context.l10n.reviewThanks);
    }
  }

  List<Widget> _actions(ServiceRequest r) {
    final l = context.l10n;
    final isPro = currentUserId == r.professionalId;
    final s = r.status;
    final actions = <Widget>[];
    Widget primary(String label, VoidCallback onTap, {Color? color}) => FilledButton(
          style: color == null ? null : FilledButton.styleFrom(backgroundColor: color),
          onPressed: _busy ? null : onTap,
          child: Text(label),
        );
    Widget secondary(String label, VoidCallback onTap) =>
        OutlinedButton(onPressed: _busy ? null : onTap, child: Text(label));

    if (isPro) {
      if (s == 'pending' || s == 'needs_info' || s == 'in_discussion') {
        actions.add(primary(l.accept, () => _setStatus(r, 'accepted'), color: BallalColors.success));
        actions.add(secondary(l.askDetails, () => _setStatus(r, 'needs_info', askNote: true)));
        actions.add(secondary(l.decline, () => _setStatus(r, 'declined', askNote: true)));
      }
      if (s == 'accepted') actions.add(primary(l.markCompleted, () => _setStatus(r, 'completed', confirm: true)));
    } else {
      if (s == 'needs_info') actions.add(primary(l.iAnswered, () => _setStatus(r, 'pending')));
      if (s == 'accepted') actions.add(primary(l.markCompleted, () => _setStatus(r, 'completed', confirm: true)));
      if (s == 'completed' && !r.hasReview) {
        actions.add(primary(l.leaveReview, () => _review(r), color: BallalColors.accent));
      }
      if (const {'pending', 'needs_info', 'in_discussion', 'accepted'}.contains(s)) {
        actions.add(secondary(l.cancelRequest, () => _setStatus(r, 'cancelled', confirm: true)));
      }
    }
    actions.add(secondary(l.discuss, () => _openChat(r)));
    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.requestDetail)),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorState(error: snap.error!, onRetry: _reload);
          if (!snap.hasData) return const LoadingView();
          final (r, history, photos) = snap.data!;
          if (r == null) return EmptyState(icon: Icons.search_off_rounded, title: l.notFound);
          final isPro = currentUserId == r.professionalId;
          final budget = formatPriceRange(r.budgetMin, r.budgetMax, null);
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              BallalCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(r.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                    StatusChip(status: r.status),
                  ]),
                  const SizedBox(height: 4),
                  Text(isPro ? l.fromClient(r.clientName ?? '') : l.toPro(r.proName ?? ''),
                      style: const TextStyle(color: BallalColors.muted)),
                  const Divider(height: 24),
                  Text(r.description, style: const TextStyle(height: 1.4)),
                  const SizedBox(height: 12),
                  if (r.locationName != null) _info(Icons.place_outlined, r.locationName!),
                  if (r.addressHint != null) _info(Icons.signpost_outlined, r.addressHint!),
                  if (r.desiredDate != null) _info(Icons.event_outlined, formatDate(r.desiredDate!)),
                  if (budget.isNotEmpty) _info(Icons.payments_outlined, l.budgetValue(budget)),
                  _info(Icons.schedule_outlined, l.sentOn(formatDate(r.createdAt))),
                ]),
              ),
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: photos[i],
                        cacheKey: '${r.id}-$i',
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ..._actions(r).map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)),
              const SizedBox(height: 8),
              Text(l.history, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              for (final h in history)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.circle, size: 12, color: requestStatusColor(h.toStatus)),
                  title: Text(requestStatusLabel(l, h.toStatus), style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text([formatDate(h.createdAt), if (h.note != null) h.note!].join('\n')),
                ),
            ]),
          );
        },
      ),
    );
  }

  Widget _info(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(icon, size: 18, color: BallalColors.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ]),
      );
}

class ReviewSheet extends StatefulWidget {
  const ReviewSheet({super.key, required this.request});
  final ServiceRequest request;

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  int _rating = 0;
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await RequestRepo.instance.review(request: widget.request, rating: _rating, comment: _comment.text);
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
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l.rateService, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(widget.request.proName ?? '', style: const TextStyle(color: BallalColors.muted)),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              iconSize: 40,
              tooltip: '$i/5',
              onPressed: () => setState(() => _rating = i),
              icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: BallalColors.star),
            ),
        ]),
        const SizedBox(height: 8),
        TextField(controller: _comment, maxLines: 4, maxLength: 1000, decoration: InputDecoration(hintText: l.reviewHint)),
        const SizedBox(height: 8),
        FilledButton(onPressed: _rating == 0 || _busy ? null : _submit, child: Text(l.publishReview)),
      ]),
    );
  }
}
