import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/formatters.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';
import '../pro/pro_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _repo = ChatRepo.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<List<ChatMessage>>? _sub;
  StreamSubscription<List<Map<String, dynamic>>>? _readSub;

  List<ChatMessage> _server = [];
  final List<ChatMessage> _older = [];
  final List<ChatMessage> _pending = [];
  ConversationSummary? _summary;
  DateTime? _otherLastRead;
  bool _iBlocked = false;
  bool _loadingOlder = false;
  bool _noMoreOlder = false;
  Object? _streamError;
  Timer? _readDebounce;

  // Messages vocaux
  final _recorder = AudioRecorder();
  bool _recording = false;
  DateTime? _recordStart;
  Timer? _recordTicker;

  @override
  void initState() {
    super.initState();
    _subscribe();
    _loadSummary();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) _loadOlder();
    });
  }

  void _subscribe() {
    _sub?.cancel();
    _sub = _repo.stream(widget.conversationId).listen(
      (msgs) {
        setState(() {
          _server = msgs;
          _streamError = null;
          final ids = msgs.map((m) => m.clientMessageId).whereType<String>().toSet();
          _pending.removeWhere((p) => ids.contains(p.clientMessageId));
        });
        _scheduleMarkRead();
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _streamError = e);
        // Reconnexion automatique après une coupure réseau.
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _subscribe();
        });
      },
    );
  }

  Future<void> _loadSummary() async {
    try {
      final s = await _repo.summary(widget.conversationId);
      if (!mounted || s == null) return;
      final blocked = await _repo.isBlocked(s.otherUserId);
      setState(() {
        _summary = s;
        _otherLastRead = s.otherLastReadAt;
        _iBlocked = blocked;
      });
      _readSub?.cancel();
      _readSub = supa
          .from('conversation_members')
          .stream(primaryKey: ['conversation_id', 'user_id'])
          .eq('conversation_id', widget.conversationId)
          .listen((rows) {
        for (final r in rows) {
          if (r['user_id'] == s.otherUserId && r['last_read_at'] != null) {
            if (mounted) setState(() => _otherLastRead = DateTime.tryParse(r['last_read_at'] as String));
          }
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  void _scheduleMarkRead() {
    _readDebounce?.cancel();
    _readDebounce = Timer(const Duration(milliseconds: 600), () => _repo.markRead(widget.conversationId));
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || _noMoreOlder) return;
    final all = _merged();
    if (all.isEmpty || _server.length < 100) return;
    setState(() => _loadingOlder = true);
    try {
      final older = await _repo.older(widget.conversationId, all.last.createdAt);
      setState(() {
        _older.addAll(older);
        _noMoreOlder = older.length < 50;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _readSub?.cancel();
    _readDebounce?.cancel();
    _recordTicker?.cancel();
    _recorder.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Du plus récent au plus ancien : en attente, puis serveur, puis historique chargé.
  List<ChatMessage> _merged() {
    final seen = <String>{};
    final out = <ChatMessage>[];
    for (final m in [..._pending.reversed, ..._server, ..._older]) {
      if (seen.add(m.id)) out.add(m);
    }
    return out;
  }

  Future<void> _sendPending(ChatMessage m, {Uint8List? bytes, String? ext}) async {
    setState(() => m.sendState = SendState.sending);
    try {
      String? path = m.attachmentPath;
      if (m.type != 'text' && path == null && bytes != null) {
        path = await _repo.uploadAttachment(widget.conversationId, bytes, m.attachmentMime!, ext!);
      }
      await _repo.send(
        conversationId: widget.conversationId,
        clientMessageId: m.clientMessageId!,
        type: m.type,
        body: m.body,
        attachmentPath: path,
        attachmentMime: m.attachmentMime,
        attachmentSize: bytes?.length,
        durationMs: m.durationMs,
      );
      if (mounted) setState(() => m.sendState = SendState.sent);
    } catch (e) {
      if (mounted) {
        setState(() => m.sendState = SendState.failed);
        showError(context, e);
      }
    }
  }

  ChatMessage _local(String type, {String? body, String? mime, int? durationMs, List<int>? bytes}) {
    final cid = _repo.newClientId();
    return ChatMessage(
      id: 'local-$cid',
      conversationId: widget.conversationId,
      senderId: currentUserId!,
      type: type,
      body: body,
      attachmentMime: mime,
      durationMs: durationMs,
      createdAt: DateTime.now(),
      clientMessageId: cid,
      sendState: SendState.sending,
      localBytes: bytes,
    );
  }

  void _sendText() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    final m = _local('text', body: text);
    setState(() => _pending.add(m));
    _sendPending(m);
  }

  Future<void> _sendImage(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 70);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      if (mounted) showInfo(context, context.l10n.photoTooLarge);
      return;
    }
    final m = _local('image', mime: 'image/jpeg', bytes: bytes);
    setState(() => _pending.add(m));
    _sendPending(m, bytes: bytes, ext: 'jpg');
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) showInfo(context, context.l10n.micDenied);
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/ballal_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 48000, sampleRate: 22050), path: path);
    setState(() {
      _recording = true;
      _recordStart = DateTime.now();
    });
    _recordTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (DateTime.now().difference(_recordStart!).inSeconds >= 120) _stopRecording(send: true);
    });
  }

  Future<void> _stopRecording({required bool send}) async {
    _recordTicker?.cancel();
    final started = _recordStart;
    final path = await _recorder.stop();
    setState(() => _recording = false);
    if (!send || path == null || started == null) {
      if (path != null) File(path).delete().ignore();
      return;
    }
    final duration = DateTime.now().difference(started);
    if (duration.inMilliseconds < 800) return; // appui accidentel
    final bytes = await File(path).readAsBytes();
    File(path).delete().ignore();
    final m = _local('audio', mime: 'audio/mp4', durationMs: duration.inMilliseconds, bytes: bytes);
    setState(() => _pending.add(m));
    _sendPending(m, bytes: bytes, ext: 'm4a');
  }

  Future<void> _menu(String action) async {
    final s = _summary;
    if (s == null) return;
    final l = context.l10n;
    switch (action) {
      case 'profile':
        context.push('/pro/${s.otherUserId}');
      case 'request':
        if (s.requestId != null) context.push('/requests/${s.requestId}');
      case 'block':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.blockTitle(s.otherName)),
            content: Text(l.blockText),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: BallalColors.danger),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.block),
              ),
            ],
          ),
        );
        if (ok == true) {
          try {
            await _repo.block(s.otherUserId);
            setState(() => _iBlocked = true);
          } catch (e) {
            if (mounted) showError(context, e);
          }
        }
      case 'unblock':
        try {
          await _repo.unblock(s.otherUserId);
          setState(() => _iBlocked = false);
        } catch (e) {
          if (mounted) showError(context, e);
        }
      case 'report':
        // On joint uniquement les 5 derniers messages reçus, avec l'accord explicite de l'utilisateur.
        final evidence = _server.where((m) => m.senderId == s.otherUserId).take(5).map((m) => m.id).toList();
        final sent = await showReportSheet(context,
            targetType: 'conversation', targetId: widget.conversationId, messageIds: evidence);
        if (sent == true && mounted) showInfo(context, l.reportSent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = _summary;
    final messages = _merged();
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: Row(children: [
          Avatar(
            url: s?.otherAvatar == null ? null : publicUrl(s!.otherIsPro ? 'pro-media' : 'avatars', s.otherAvatar!),
            name: s?.otherName ?? '',
            size: 38,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(s?.otherName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ]),
        actions: [
          PopupMenuButton<String>(
            onSelected: _menu,
            itemBuilder: (_) => [
              if (s?.otherIsPro ?? false) PopupMenuItem(value: 'profile', child: Text(l.seeProfile)),
              if (s?.requestId != null) PopupMenuItem(value: 'request', child: Text(l.seeRequest)),
              PopupMenuItem(value: _iBlocked ? 'unblock' : 'block', child: Text(_iBlocked ? l.unblock : l.block)),
              PopupMenuItem(value: 'report', child: Text(l.report)),
            ],
          ),
        ],
      ),
      body: Column(children: [
        if (_streamError != null)
          Container(
            width: double.infinity,
            color: BallalColors.warning.withValues(alpha: 0.15),
            padding: const EdgeInsets.all(8),
            child: Text(l.reconnecting, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
          ),
        Expanded(
          child: messages.isEmpty
              ? EmptyState(icon: Icons.waving_hand_outlined, title: l.chatEmptyTitle, message: l.chatEmptyText)
              : ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length + (_loadingOlder ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i >= messages.length) {
                      return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
                    }
                    final m = messages[i];
                    final mine = m.senderId == currentUserId;
                    final read = mine && _otherLastRead != null && !_otherLastRead!.isBefore(m.createdAt);
                    return _Bubble(
                      message: m,
                      mine: mine,
                      read: read,
                      onRetry: m.sendState == SendState.failed
                          ? () => _sendPending(m, bytes: m.localBytes == null ? null : Uint8List.fromList(m.localBytes!),
                              ext: m.type == 'image' ? 'jpg' : 'm4a')
                          : null,
                    );
                  },
                ),
        ),
        if (_iBlocked)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(children: [
              Text(l.youBlocked, textAlign: TextAlign.center),
              TextButton(onPressed: () => _menu('unblock'), child: Text(l.unblock)),
            ]),
          )
        else
          _composer(),
      ]),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        color: Colors.white,
        child: _recording
            ? Row(children: [
                IconButton(
                  tooltip: context.l10n.cancel,
                  icon: const Icon(Icons.delete_outline, color: BallalColors.danger),
                  onPressed: () => _stopRecording(send: false),
                ),
                const Icon(Icons.fiber_manual_record, color: BallalColors.danger, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${context.l10n.recording}  ${_fmtDuration(DateTime.now().difference(_recordStart ?? DateTime.now()))}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton.filled(
                  tooltip: context.l10n.send,
                  onPressed: () => _stopRecording(send: true),
                  icon: const Icon(Icons.send_rounded),
                ),
              ])
            : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                IconButton(
                  tooltip: context.l10n.addPhoto,
                  icon: const Icon(Icons.add_photo_alternate_outlined, color: BallalColors.primary),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        ListTile(
                          leading: const Icon(Icons.photo_camera_outlined),
                          title: Text(context.l10n.camera),
                          onTap: () {
                            Navigator.pop(ctx);
                            _sendImage(ImageSource.camera);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library_outlined),
                          title: Text(context.l10n.gallery),
                          onTap: () {
                            Navigator.pop(ctx);
                            _sendImage(ImageSource.gallery);
                          },
                        ),
                      ]),
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 4000,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: context.l10n.writeMessage,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      fillColor: BallalColors.bg,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _input.text.trim().isEmpty
                    ? IconButton.filled(
                        tooltip: context.l10n.voiceMessage,
                        onPressed: _startRecording,
                        icon: const Icon(Icons.mic_rounded),
                      )
                    : IconButton.filled(
                        tooltip: context.l10n.send,
                        onPressed: _sendText,
                        icon: const Icon(Icons.send_rounded),
                      ),
              ]),
      ),
    );
  }
}

String _fmtDuration(Duration d) =>
    '${d.inMinutes.toString().padLeft(1, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, required this.read, this.onRetry});
  final ChatMessage message;
  final bool mine;
  final bool read;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bg = mine ? BallalColors.primary : Colors.white;
    final fg = mine ? Colors.white : BallalColors.text;
    Widget content;
    switch (message.type) {
      case 'image':
        content = _ImageContent(message: message);
      case 'audio':
        content = VoiceMessagePlayer(message: message, color: fg);
      default:
        content = Text(message.body ?? '', style: TextStyle(color: fg, fontSize: 15, height: 1.3));
    }
    Widget status = const SizedBox.shrink();
    if (mine) {
      status = switch (message.sendState) {
        SendState.sending => Icon(Icons.schedule, size: 13, color: fg.withValues(alpha: 0.8), semanticLabel: l.sending),
        SendState.failed => const Icon(Icons.error_outline, size: 14, color: BallalColors.accentSoft),
        SendState.sent => Icon(read ? Icons.done_all_rounded : Icons.done_rounded,
            size: 15, color: read ? BallalColors.accentSoft : fg.withValues(alpha: 0.8),
            semanticLabel: read ? l.read : l.sent),
      };
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: onRetry,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: EdgeInsets.all(message.type == 'image' ? 4 : 10),
          decoration: BoxDecoration(
            color: message.sendState == SendState.failed ? BallalColors.danger : bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
            boxShadow: mine ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            content,
            const SizedBox(height: 3),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: message.type == 'image' ? 6 : 0),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (message.sendState == SendState.failed)
                  Text(l.tapToRetry, style: const TextStyle(color: Colors.white, fontSize: 11)),
                Text(formatChatTime(message.createdAt), style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.7))),
                const SizedBox(width: 3),
                status,
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(14);
    if (message.localBytes != null) {
      return ClipRRect(
        borderRadius: r,
        child: Image.memory(Uint8List.fromList(message.localBytes!), width: 220, height: 220, fit: BoxFit.cover),
      );
    }
    final path = message.attachmentPath;
    if (path == null) return const SizedBox(width: 220, height: 220);
    return FutureBuilder<String>(
      future: ChatRepo.instance.signedUrl(path),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(width: 220, height: 220, child: Center(child: CircularProgressIndicator()));
        }
        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
              body: InteractiveViewer(child: Center(child: CachedNetworkImage(imageUrl: snap.data!, cacheKey: path))),
            ),
          )),
          child: ClipRRect(
            borderRadius: r,
            child: CachedNetworkImage(
              imageUrl: snap.data!,
              cacheKey: path, // l'URL signée change, le fichier non
              width: 220,
              height: 220,
              fit: BoxFit.cover,
              memCacheWidth: 600,
            ),
          ),
        );
      },
    );
  }
}

class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({super.key, required this.message, required this.color});
  final ChatMessage message;
  final Color color;

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final _player = AudioPlayer();
  bool _loaded = false;
  bool _loading = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final path = widget.message.attachmentPath;
    if (path == null) return;
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (!_loaded) {
      setState(() => _loading = true);
      try {
        await _player.setUrl(await ChatRepo.instance.signedUrl(path));
        _loaded = true;
      } catch (e) {
        if (mounted) showError(context, e);
        return;
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
    if (_player.processingState == ProcessingState.completed) await _player.seek(Duration.zero);
    await _player.play();
  }

  @override
  Widget build(BuildContext context) {
    final total = Duration(milliseconds: widget.message.durationMs ?? 0);
    return SizedBox(
      width: 200,
      child: StreamBuilder<PlayerState>(
        stream: _player.playerStateStream,
        builder: (context, snap) {
          final playing = snap.data?.playing ?? false;
          return Row(children: [
            IconButton(
              tooltip: context.l10n.voiceMessage,
              onPressed: _toggle,
              color: widget.color,
              icon: _loading
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: widget.color))
                  : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
            ),
            Expanded(
              child: StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (context, pos) {
                  final p = pos.data ?? Duration.zero;
                  final ratio = total.inMilliseconds == 0 ? 0.0 : (p.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    LinearProgressIndicator(
                      value: ratio,
                      color: widget.color,
                      backgroundColor: widget.color.withValues(alpha: 0.25),
                    ),
                    const SizedBox(height: 4),
                    Text(_fmtDuration(playing ? p : total), style: TextStyle(fontSize: 11, color: widget.color)),
                  ]);
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}
