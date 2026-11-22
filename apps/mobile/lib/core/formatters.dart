import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';

final _gnf = NumberFormat.decimalPattern('fr');

String formatGnf(num value) => '${_gnf.format(value)} GNF';

String formatPriceRange(int? min, int? max, String? unit) {
  String s;
  if (min != null && max != null && max != min) {
    s = '${_gnf.format(min)} – ${formatGnf(max)}';
  } else if (min != null) {
    s = formatGnf(min);
  } else if (max != null) {
    s = formatGnf(max);
  } else {
    return '';
  }
  return unit == null || unit.isEmpty ? s : '$s · $unit';
}

String formatRating(num v) => NumberFormat('0.0', 'fr').format(v);

String formatKm(num v) => '${NumberFormat('0.#', 'fr').format(v)} km';

/// « à l'instant », « il y a 5 min », « hier », « 12/11 »…
String timeAgo(AppLocalizations l, DateTime date) {
  final d = DateTime.now().difference(date.toLocal());
  if (d.inMinutes < 1) return l.timeNow;
  if (d.inMinutes < 60) return l.timeMinutes(d.inMinutes.toString());
  if (d.inHours < 24) return l.timeHours(d.inHours.toString());
  if (d.inDays == 1) return l.timeYesterday;
  if (d.inDays < 7) return DateFormat.EEEE('fr').format(date.toLocal());
  return DateFormat('dd/MM/yy', 'fr').format(date.toLocal());
}

String formatChatTime(DateTime date) => DateFormat.Hm('fr').format(date.toLocal());

String formatDate(DateTime date) => DateFormat.yMMMd('fr').format(date.toLocal());

/// Normalise un numéro saisi en Guinée vers le format international.
String? normalizeGuineaPhone(String input, {String countryCode = '+224'}) {
  final digits = input.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.isEmpty) return null;
  String full;
  if (digits.startsWith('+')) {
    full = digits;
  } else if (digits.startsWith('00')) {
    full = '+${digits.substring(2)}';
  } else if (digits.startsWith('224') && digits.length == 12) {
    full = '+$digits';
  } else {
    full = '$countryCode$digits';
  }
  final ok = RegExp(r'^\+[0-9]{8,15}$').hasMatch(full);
  if (!ok) return null;
  // Guinée : 9 chiffres après +224, commençant par 6 (mobile) ou 3 (fixe).
  if (full.startsWith('+224') && !RegExp(r'^\+224[36][0-9]{8}$').hasMatch(full)) return null;
  return full;
}

/// E-mail nettoyé (minuscules, sans espaces) ou null s'il est invalide.
String? normalizeEmail(String input) {
  final e = input.trim().toLowerCase();
  return RegExp(r'^[^@\s]+@[^@\s]+\.[a-z]{2,}$').hasMatch(e) ? e : null;
}
