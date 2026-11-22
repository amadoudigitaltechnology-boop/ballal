import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/gen/app_localizations.dart';

SupabaseClient get supa => Supabase.instance.client;

String? get currentUserId => supa.auth.currentUser?.id;

String publicUrl(String bucket, String path) => supa.storage.from(bucket).getPublicUrl(path);

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Traduit les erreurs serveur en messages simples pour l'utilisateur.
String friendlyError(BuildContext context, Object error) {
  final l = context.l10n;
  final raw = error.toString();
  if (error is PostgrestException) {
    final m = error.message;
    if (m.startsWith('rate_limited')) return l.errRateLimited;
    if (m.contains('profile_incomplete')) return l.errProfileIncomplete;
    if (m.contains('blocked')) return l.errBlocked;
    if (m.startsWith('invalid_transition')) return l.errInvalidTransition;
    if (m.contains('account_inactive')) return l.errAccountInactive;
    if (m.contains('row-level security') || m.contains('forbidden') || error.code == '42501') {
      return l.errForbidden;
    }
    if (error.code == '23505') return l.errDuplicate;
  }
  if (error is AuthException) {
    final m = error.message.toLowerCase();
    if (m.contains('expired') || m.contains('invalid')) return l.errOtpInvalid;
    if (m.contains('rate') || m.contains('seconds')) return l.errRateLimited;
    return l.errAuth;
  }
  if (raw.contains('SocketException') || raw.contains('Failed host lookup') || raw.contains('ClientException')) {
    return l.errNetwork;
  }
  return l.errGeneric;
}

void showError(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(friendlyError(context, error))));
}

void showInfo(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
