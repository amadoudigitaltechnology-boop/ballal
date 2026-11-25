import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supa.dart';

/// État global de la session : connexion, rôles, mode actif (client / pro).
class Session extends ChangeNotifier {
  Session._();
  static final Session instance = Session._();

  StreamSubscription<AuthState>? _sub;
  bool initialized = false;
  bool onboardingSeen = false;

  Set<String> roles = {};
  String activeMode = 'client';
  String? fullName;
  String? avatarPath;
  String status = 'active';

  User? get user => supa.auth.currentUser;
  bool get isSignedIn => user != null;
  bool get isClient => roles.contains('client');
  bool get hasProRole => roles.contains('professional');
  bool get isProMode => activeMode == 'professional' && hasProRole;
  bool get isSuspended => isSignedIn && status != 'active';
  bool get needsSetup =>
      isSignedIn && ((fullName ?? '').trim().isEmpty || !(isClient || hasProRole));

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    onboardingSeen = prefs.getBool('onboarding_seen') ?? false;
    _sub = supa.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.signedOut ||
          state.event == AuthChangeEvent.userUpdated) {
        refresh();
      }
    });
    await refresh();
    initialized = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!isSignedIn) {
      roles = {};
      fullName = null;
      avatarPath = null;
      activeMode = 'client';
      status = 'active';
      notifyListeners();
      return;
    }
    final uid = user!.id;
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        supa.from('profiles').select('full_name, avatar_path, status').eq('id', uid).maybeSingle(),
        supa.from('user_roles').select('role').eq('user_id', uid),
        supa.from('user_preferences').select('active_mode').eq('user_id', uid).maybeSingle(),
      ]);
      final profile = results[0] as Map<String, dynamic>?;
      final roleRows = results[1] as List<dynamic>;
      final prefs = results[2] as Map<String, dynamic>?;
      fullName = profile?['full_name'] as String?;
      avatarPath = profile?['avatar_path'] as String?;
      status = (profile?['status'] as String?) ?? 'active';
      roles = roleRows.map((r) => (r as Map<String, dynamic>)['role'] as String).toSet();
      activeMode = (prefs?['active_mode'] as String?) ?? 'client';
      if (activeMode == 'professional' && !hasProRole) activeMode = 'client';
    } catch (e) {
      if (kDebugMode) debugPrint('Session.refresh: $e');
    }
    notifyListeners();
  }

  Future<void> setMode(String mode) async {
    if (!isSignedIn) return;
    await supa.from('user_preferences').update({'active_mode': mode}).eq('user_id', user!.id);
    activeMode = mode;
    notifyListeners();
  }

  /// Active un rôle côté serveur (crée le profil client ou pro).
  Future<void> activateRole(String role) async {
    await supa.rpc('activate_role', params: {'p_role': role});
    await refresh();
  }

  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    onboardingSeen = true;
    notifyListeners();
  }

  /// Appelé juste avant la déconnexion (ex. retirer le jeton push de l'appareil).
  Future<void> Function()? beforeSignOut;

  Future<void> signOut() async {
    try {
      await beforeSignOut?.call();
    } catch (_) {}
    await supa.auth.signOut();
    await refresh();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
