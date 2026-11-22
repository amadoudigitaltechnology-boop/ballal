import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../data/repositories.dart';
import 'session.dart';
import 'supa.dart';

/// Compteurs de non-lus (badges messages / cloche), mis à jour en temps réel.
class Unread extends ChangeNotifier {
  Unread._();
  static final instance = Unread._();

  int messages = 0;
  int notifications = 0;
  RealtimeChannel? _channel;
  String? _channelUser;

  void start() {
    Session.instance.addListener(_onSession);
    _onSession();
  }

  void _onSession() {
    final uid = Session.instance.user?.id;
    if (uid == _channelUser) return;
    if (_channel != null) {
      supa.removeChannel(_channel!);
      _channel = null;
    }
    _channelUser = uid;
    if (uid == null) {
      messages = 0;
      notifications = 0;
      notifyListeners();
      return;
    }
    _channel = NotificationRepo.instance.subscribe(refresh);
    refresh();
  }

  Future<void> refresh() async {
    if (!Session.instance.isSignedIn) return;
    try {
      final c = await NotificationRepo.instance.unreadCounts();
      messages = c.messages;
      notifications = c.notifications;
      notifyListeners();
    } catch (_) {/* hors ligne : on garde les derniers compteurs */}
  }
}
