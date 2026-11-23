import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'session.dart';
import 'supa.dart';
import 'theme.dart';
import 'unread.dart';

/// Messages reçus quand l'application est fermée : Android les affiche tout seul,
/// rien à faire ici (la fonction doit seulement exister au niveau racine).
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {}

/// Notifications push (Firebase Cloud Messaging).
/// - enregistre le jeton de l'appareil pour le compte connecté ;
/// - au premier plan : bandeau discret en haut de l'écran ;
/// - toucher une notification ouvre le bon écran (message, demande…).
class PushService {
  PushService._();
  static final instance = PushService._();

  bool _ready = false;
  String? _token;
  GoRouter? _router;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  GlobalKey<ScaffoldMessengerState> get messengerKey => _messengerKey;

  /// À appeler une fois au démarrage. Sans fichier Firebase, l'application fonctionne sans push.
  Future<void> init() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
      _ready = true;
    } catch (e) {
      debugPrint('Push désactivé : $e');
      return;
    }
    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_open);
    FirebaseMessaging.instance.onTokenRefresh.listen((t) => _register(t));
    Session.instance.beforeSignOut = () async {
      final t = _token;
      if (t != null) await supa.rpc('unregister_device_token', params: {'p_token': t});
    };
    Session.instance.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  void attachRouter(GoRouter router) {
    _router = router;
    if (!_ready) return;
    // Application lancée en touchant une notification.
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m != null) Future.delayed(const Duration(milliseconds: 600), () => _open(m));
    });
  }

  String? _lastUser;
  Future<void> _onSessionChanged() async {
    final uid = Session.instance.user?.id;
    if (uid == _lastUser) return;
    final previous = _lastUser;
    _lastUser = uid;
    if (uid == null) {
      // Déconnexion : l'appareil ne doit plus recevoir les notifications de l'ancien compte.
      if (previous != null && _token != null) {
        try {
          await FirebaseMessaging.instance.deleteToken();
        } catch (_) {}
        _token = null;
      }
      return;
    }
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _register(token);
    } catch (e) {
      debugPrint('Push : $e');
    }
  }

  Future<void> _register(String token) async {
    _token = token;
    if (!Session.instance.isSignedIn) return;
    try {
      await supa.rpc('register_device_token', params: {
        'p_token': token,
        'p_platform': Platform.isIOS ? 'ios' : 'android',
      });
    } catch (e) {
      debugPrint('Push register : $e');
    }
  }

  void _open(RemoteMessage m) {
    final route = m.data['route'] as String?;
    if (route == null || !route.startsWith('/') || _router == null) return;
    _router!.push(route);
  }

  void _onForeground(RemoteMessage m) {
    Unread.instance.refresh();
    final n = m.notification;
    if (n == null) return;
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      backgroundColor: BallalColors.primaryDark,
      duration: const Duration(seconds: 4),
      content: Row(children: [
        const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n.title ?? '', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
            if ((n.body ?? '').isNotEmpty)
              Text(n.body!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
          ]),
        ),
      ]),
      action: m.data['route'] == null ? null : SnackBarAction(label: 'Voir', textColor: BallalColors.accent, onPressed: () => _open(m)),
    ));
  }
}
