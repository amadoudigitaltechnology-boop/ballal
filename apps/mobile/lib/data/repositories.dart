import 'dart:typed_data';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/config.dart';
import '../core/supa.dart';
import 'models.dart';

const _uuid = Uuid();

List<Map<String, dynamic>> _rows(dynamic data) =>
    (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

// ═════════════ Référentiels (mis en cache) ═════════════
class CatalogRepo {
  CatalogRepo._();
  static final instance = CatalogRepo._();

  List<Category>? _categories;
  List<Place>? _places;

  Future<List<Category>> categories({bool force = false}) async {
    if (_categories != null && !force) return _categories!;
    final data = await supa.from('categories').select('id, name, slug, parent_id, icon').order('sort_order');
    _categories = _rows(data).map(Category.fromMap).toList();
    return _categories!;
  }

  Future<List<Category>> families() async => (await categories()).where((c) => c.isFamily).toList();

  Future<List<Category>> trades({String? familyId}) async =>
      (await categories()).where((c) => !c.isFamily && (familyId == null || c.parentId == familyId)).toList();

  Future<List<Place>> places({bool force = false}) async {
    if (_places != null && !force) return _places!;
    final data = await supa.from('locations').select('id, name, level, parent_id, lat, lng').order('name');
    _places = _rows(data).map(Place.fromMap).toList();
    return _places!;
  }

  Future<List<Place>> children(String? parentId) async =>
      (await places()).where((p) => p.parentId == parentId).toList();

  /// Ajoute un quartier (ou une commune) absent de la liste. Renvoie l'existant s'il y est déjà.
  Future<Place> addLocation(String parentId, String name) async {
    final row = await supa.rpc('add_location', params: {'p_parent': parentId, 'p_name': name});
    final place = Place.fromMap(Map<String, dynamic>.from(row as Map));
    final cache = _places;
    if (cache != null && !cache.any((p) => p.id == place.id)) {
      cache.add(place);
      cache.sort((a, b) => a.name.compareTo(b.name));
    }
    return place;
  }

  /// Libellé lisible « Kipé, Ratoma ».
  Future<String> label(Place p) async {
    final all = await places();
    final parent = all.where((x) => x.id == p.parentId).firstOrNull;
    if (parent == null || parent.level == 'region' || parent.level == 'country') return p.name;
    return '${p.name}, ${parent.name}';
  }
}

// ═════════════ Réglages publics et annonces ═════════════
class AppSettingsRepo {
  AppSettingsRepo._();
  static final instance = AppSettingsRepo._();

  Future<Map<String, dynamic>> publicSettings() async {
    final rows = await supa.from('app_settings').select('key, value');
    return {for (final r in (rows as List)) (r as Map)['key'] as String: r['value']};
  }
}

class Ad {
  Ad({required this.id, required this.title, this.body, this.imagePath, this.linkUrl, this.cta});
  final String id;
  final String title;
  final String? body;
  final String? imagePath;
  final String? linkUrl;
  final String? cta;

  factory Ad.fromMap(Map<String, dynamic> m) => Ad(
        id: m['id'] as String,
        title: m['title'] as String,
        body: m['body'] as String?,
        imagePath: m['image_path'] as String?,
        linkUrl: m['link_url'] as String?,
        cta: m['cta'] as String?,
      );
}

class AdsRepo {
  AdsRepo._();
  static final instance = AdsRepo._();
  List<Ad>? _cache;
  DateTime? _at;
  final Set<String> _seen = {};

  /// Annonces actives (cache de 10 minutes). Jamais bloquant : en cas d'erreur, aucune annonce.
  Future<List<Ad>> active() async {
    if (_cache != null && _at != null && DateTime.now().difference(_at!).inMinutes < 10) return _cache!;
    try {
      final rows = await supa
          .from('ads')
          .select('id, title, body, image_path, link_url, cta')
          .order('created_at', ascending: false)
          .limit(10);
      _cache = (rows as List).map((e) => Ad.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      _at = DateTime.now();
    } catch (_) {
      _cache ??= [];
    }
    return _cache!;
  }

  void impression(String id) {
    if (!_seen.add(id)) return;
    _track(id, false);
  }

  void click(String id) => _track(id, true);

  Future<void> _track(String id, bool click) async {
    try {
      await supa.rpc('track_ad', params: {'p_ad': id, 'p_click': click});
    } catch (_) {}
  }
}

// ═════════════ Professionnels ═════════════
class ProRepo {
  ProRepo._();
  static final instance = ProRepo._();

  static const pageSize = 20;

  Future<List<ProCard>> search(SearchFilters f, {int offset = 0}) async {
    final data = await supa.rpc('search_professionals', params: {
      'p_query': f.query.trim().isEmpty ? null : f.query.trim(),
      'p_category': f.category?.id,
      'p_location': f.place?.id,
      'p_lat': f.lat,
      'p_lng': f.lng,
      'p_radius_km': f.usesGps ? (f.radiusKm ?? 10) : null,
      'p_available_only': f.availableOnly,
      'p_min_rating': f.minRating,
      'p_verified_only': f.verifiedOnly,
      'p_sort': f.sort,
      'p_limit': pageSize,
      'p_offset': offset,
    });
    return _rows(data).map(ProCard.fromMap).toList();
  }

  /// Recommandations ; si le serveur échoue, repli sur une recherche classique triée par note.
  Future<List<ProCard>> recommend({Place? place, double? lat, double? lng}) async {
    try {
      final data = await supa.rpc('recommend_professionals', params: {
        'p_location': place?.id,
        'p_lat': lat,
        'p_lng': lng,
        'p_limit': 10,
      });
      return _rows(data).map(ProCard.fromMap).toList();
    } catch (_) {
      return search(SearchFilters(place: place, sort: 'rating'));
    }
  }

  Future<void> logRecoEvent(String proId, String action, {int? position}) async {
    try {
      await supa.rpc('log_recommendation_event', params: {
        'p_pro': proId,
        'p_action': action,
        'p_position': position,
        'p_context': {'engine': 'rules-v1'},
      });
    } catch (_) {/* analytics non bloquant */}
  }

  static const _detailSelect = '*, location:locations(name), '
      'service_areas(location:locations(name)), '
      'professional_categories(category:categories(id, name, slug, parent_id, icon)), '
      'opening_hours(weekday, opens, closes)';

  Future<ProDetail?> detail(String proId) async {
    final data = await supa.from('professional_profiles').select(_detailSelect).eq('user_id', proId).maybeSingle();
    return data == null ? null : ProDetail.fromMap(data);
  }

  Future<List<ProService>> services(String proId, {bool onlyPublished = true}) async {
    var q = supa.from('services').select('*, service_media(storage_path, sort_order)').eq('professional_id', proId);
    if (onlyPublished) q = q.eq('status', 'published');
    final data = await q.order('created_at');
    return _rows(data).map(ProService.fromMap).toList();
  }

  Future<List<Review>> reviews(String proId, {int offset = 0}) async {
    final data = await supa
        .from('reviews')
        .select('id, rating, comment, created_at, review_replies(body)')
        .eq('professional_id', proId)
        .eq('status', 'published')
        .order('created_at', ascending: false)
        .range(offset, offset + 19);
    return _rows(data).map(Review.fromMap).toList();
  }

  Future<List<String>> portfolio(String proId) async {
    final data = await supa
        .from('portfolio_items')
        .select('storage_path')
        .eq('professional_id', proId)
        .order('created_at', ascending: false)
        .limit(30);
    return _rows(data).map((r) => r['storage_path'] as String).toList();
  }

  Future<({String? phone, String? whatsapp})> contact(String proId) async {
    final data = await supa.rpc('get_professional_contact', params: {'p_pro': proId});
    final rows = _rows(data);
    if (rows.isEmpty) return (phone: null, whatsapp: null);
    return (phone: rows.first['phone'] as String?, whatsapp: rows.first['whatsapp'] as String?);
  }

  Future<void> recordView(String proId) async {
    try {
      await supa.rpc('record_profile_view', params: {'p_pro': proId});
    } catch (_) {}
  }

  // Favoris
  Future<bool> isFavorite(String proId) async {
    final uid = currentUserId;
    if (uid == null) return false;
    final data = await supa.from('favorites').select('professional_id')
        .eq('client_id', uid).eq('professional_id', proId).maybeSingle();
    return data != null;
  }

  Future<void> setFavorite(String proId, bool value) async {
    final uid = currentUserId!;
    if (value) {
      await supa.from('favorites').upsert({'client_id': uid, 'professional_id': proId});
    } else {
      await supa.from('favorites').delete().eq('client_id', uid).eq('professional_id', proId);
    }
  }

  Future<List<ProCard>> favorites() async {
    final uid = currentUserId!;
    final data = await supa
        .from('favorites')
        .select('pro:professional_profiles(user_id, display_name, slug, headline, logo_path, availability, '
            'rating_avg, rating_count, identity_verified, company_verified, location:locations(name))')
        .eq('client_id', uid)
        .order('created_at', ascending: false);
    return _rows(data)
        .map((r) => r['pro'])
        .whereType<Map<String, dynamic>>()
        .map((p) => ProCard.fromMap({
              ...p,
              'professional_id': p['user_id'],
              'location_name': (p['location'] as Map<String, dynamic>?)?['name'],
              'reasons': const <String>[],
            }))
        .toList();
  }

  // ─── Espace professionnel ───
  Future<Map<String, dynamic>?> myProfile() async {
    final uid = currentUserId!;
    return supa.from('professional_profiles')
        .select('*, professional_categories(category_id), service_areas(location_id)')
        .eq('user_id', uid)
        .maybeSingle();
  }

  Future<Map<String, dynamic>?> myContacts() async =>
      supa.from('professional_contacts').select().eq('user_id', currentUserId!).maybeSingle();

  Future<void> saveMyProfile({
    required Map<String, dynamic> profile,
    required Map<String, dynamic> contacts,
    required Set<String> categoryIds,
    required Set<String> areaIds,
    String? primaryCategoryId,
  }) async {
    final uid = currentUserId!;
    final publish = profile.remove('is_published') as bool?;
    await supa.from('professional_profiles').update(profile).eq('user_id', uid);
    await supa.from('professional_contacts').upsert({...contacts, 'user_id': uid});

    final current = _rows(await supa.from('professional_categories').select('category_id').eq('professional_id', uid))
        .map((r) => r['category_id'] as String)
        .toSet();
    final toRemove = current.difference(categoryIds);
    final toAdd = categoryIds.difference(current);
    if (toRemove.isNotEmpty) {
      await supa.from('professional_categories').delete().eq('professional_id', uid).inFilter('category_id', toRemove.toList());
    }
    if (toAdd.isNotEmpty) {
      await supa.from('professional_categories').insert(toAdd
          .map((c) => {'professional_id': uid, 'category_id': c, 'is_primary': c == primaryCategoryId})
          .toList());
    }

    final currentAreas = _rows(await supa.from('service_areas').select('location_id').eq('professional_id', uid))
        .map((r) => r['location_id'] as String)
        .toSet();
    final areasRemove = currentAreas.difference(areaIds);
    final areasAdd = areaIds.difference(currentAreas);
    if (areasRemove.isNotEmpty) {
      await supa.from('service_areas').delete().eq('professional_id', uid).inFilter('location_id', areasRemove.toList());
    }
    if (areasAdd.isNotEmpty) {
      await supa.from('service_areas').insert(areasAdd.map((a) => {'professional_id': uid, 'location_id': a}).toList());
    }

    // La publication est faite en dernier : le serveur vérifie que le profil est complet.
    if (publish != null) {
      await supa.from('professional_profiles').update({'is_published': publish}).eq('user_id', uid);
    }
  }

  Future<void> setAvailability(String value) async {
    await supa.from('professional_profiles').update({'availability': value}).eq('user_id', currentUserId!);
  }

  /// Enregistre un service et ses photos (nouvelles photos ajoutées, photos retirées supprimées).
  Future<void> saveService(Map<String, dynamic> service,
      {String? id, List<Uint8List> newPhotos = const [], List<String> removedPhotos = const []}) async {
    final uid = currentUserId!;
    String serviceId;
    if (id == null) {
      final row = await supa.from('services').insert({...service, 'professional_id': uid}).select('id').single();
      serviceId = row['id'] as String;
    } else {
      await supa.from('services').update(service).eq('id', id).eq('professional_id', uid);
      serviceId = id;
    }
    if (removedPhotos.isNotEmpty) {
      await supa.from('service_media').delete().eq('service_id', serviceId).inFilter('storage_path', removedPhotos);
      try {
        await supa.storage.from('pro-media').remove(removedPhotos);
      } catch (_) {}
    }
    var order = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final bytes in newPhotos) {
      final path = '$uid/services/${_uuid.v4()}.jpg';
      await supa.storage.from('pro-media').uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
      await supa.from('service_media').insert({'service_id': serviceId, 'storage_path': path, 'sort_order': order++});
    }
  }

  /// Mes dossiers de vérification (identité / entreprise), du plus récent au plus ancien.
  Future<List<Map<String, dynamic>>> myVerifications() async {
    final rows = await supa
        .from('verification_documents')
        .select('id, doc_type, status, rejection_reason, created_at')
        .eq('user_id', currentUserId!)
        .order('created_at', ascending: false);
    return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Envoie une pièce (photo) dans l'espace privé, puis crée le dossier « en attente ».
  Future<void> submitVerification(String docType, Uint8List bytes,
      {String? paymentReference, String? paymentMethod, int? amountGnf}) async {
    final uid = currentUserId!;
    final path = '$uid/${_uuid.v4()}.jpg';
    await supa.storage.from('verification-docs').uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    try {
      await supa.from('verification_documents').insert({
        'user_id': uid,
        'doc_type': docType,
        'storage_path': path,
        'payment_reference': paymentReference,
        'payment_method': paymentMethod,
        'amount_gnf': amountGnf,
      });
    } catch (e) {
      try {
        await supa.storage.from('verification-docs').remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> archiveService(String id) async {
    await supa.from('services').update({'status': 'archived'}).eq('id', id);
  }

  /// Sort un service des archives et le republie.
  Future<void> restoreService(String id) async {
    await supa.from('services').update({'status': 'published'}).eq('id', id);
  }

  Future<Map<String, int>> dashboardStats() async {
    final uid = currentUserId!;
    final reqs = _rows(await supa.from('service_requests').select('status').eq('professional_id', uid));
    final profile = await supa.from('professional_profiles').select('profile_views').eq('user_id', uid).maybeSingle();
    int favCount = 0;
    try {
      favCount = ((await supa.rpc('count_my_followers')) as num?)?.toInt() ?? 0;
    } catch (_) {}
    return {
      'new': reqs.where((r) => r['status'] == 'pending').length,
      'active': reqs.where((r) => ['needs_info', 'in_discussion', 'accepted'].contains(r['status'])).length,
      'done': reqs.where((r) => r['status'] == 'completed').length,
      'views': (profile?['profile_views'] as num?)?.toInt() ?? 0,
      'favorites': favCount,
    };
  }
}

// ═════════════ Demandes ═════════════
class RequestRepo {
  RequestRepo._();
  static final instance = RequestRepo._();

  static const _select = '*, location:locations(name), '
      'client:profiles!service_requests_client_id_fkey(full_name), '
      'pro:professional_profiles!service_requests_professional_id_fkey(display_name), '
      'reviews(id)';

  Future<String> create({
    required String professionalId,
    String? serviceId,
    String? categoryId,
    required String title,
    required String description,
    String? locationId,
    String? addressHint,
    DateTime? desiredDate,
    int? budgetMin,
    int? budgetMax,
    List<Uint8List> photos = const [],
  }) async {
    final row = await supa.from('service_requests').insert({
      'client_id': currentUserId,
      'professional_id': professionalId,
      'service_id': serviceId,
      'category_id': categoryId,
      'title': title,
      'description': description,
      'location_id': locationId,
      'address_hint': addressHint,
      'desired_date': desiredDate?.toIso8601String().substring(0, 10),
      'budget_min': budgetMin,
      'budget_max': budgetMax,
    }).select('id').single();
    final id = row['id'] as String;
    for (final bytes in photos) {
      final path = '$id/${_uuid.v4()}.jpg';
      await supa.storage.from('request-attachments')
          .uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
      await supa.from('request_attachments')
          .insert({'request_id': id, 'storage_path': path, 'mime': 'image/jpeg', 'size_bytes': bytes.length});
    }
    return id;
  }

  /// [asPro] : demandes reçues (mode pro) ou envoyées (mode client).
  Future<List<ServiceRequest>> mine({required bool asPro, List<String>? statuses}) async {
    final uid = currentUserId!;
    var q = supa.from('service_requests').select(_select).eq(asPro ? 'professional_id' : 'client_id', uid);
    if (statuses != null) q = q.inFilter('status', statuses);
    final data = await q.order('created_at', ascending: false).limit(100);
    return _rows(data).map(ServiceRequest.fromMap).toList();
  }

  Future<ServiceRequest?> get(String id) async {
    final data = await supa.from('service_requests').select(_select).eq('id', id).maybeSingle();
    return data == null ? null : ServiceRequest.fromMap(data);
  }

  Future<List<StatusChange>> history(String id) async {
    final data = await supa.from('request_status_history')
        .select('to_status, note, created_at').eq('request_id', id).order('created_at');
    return _rows(data).map(StatusChange.fromMap).toList();
  }

  Future<List<String>> attachmentUrls(String id) async {
    final rows = _rows(await supa.from('request_attachments').select('storage_path').eq('request_id', id));
    final urls = <String>[];
    for (final r in rows) {
      urls.add(await supa.storage.from('request-attachments').createSignedUrl(r['storage_path'] as String, 3600));
    }
    return urls;
  }

  Future<void> setStatus(String id, String status, {String? note}) async {
    await supa.rpc('update_request_status', params: {'p_request': id, 'p_status': status, 'p_note': note});
  }

  Future<void> review({required ServiceRequest request, required int rating, String? comment}) async {
    await supa.from('reviews').insert({
      'request_id': request.id,
      'client_id': currentUserId,
      'professional_id': request.professionalId,
      'rating': rating,
      'comment': (comment ?? '').trim().isEmpty ? null : comment!.trim(),
    });
  }
}

// ═════════════ Messagerie ═════════════
class ChatRepo {
  ChatRepo._();
  static final instance = ChatRepo._();

  final Map<String, String> _signedUrlCache = {};

  Future<String> start({String? professionalId, String? requestId}) async {
    final id = await supa.rpc('start_conversation', params: {
      'p_professional': professionalId,
      'p_request': requestId,
    });
    return id as String;
  }

  Future<List<ConversationSummary>> list() async {
    final data = await supa.rpc('list_my_conversations', params: {'p_limit': 50});
    return _rows(data).map(ConversationSummary.fromMap).toList();
  }

  Future<ConversationSummary?> summary(String conversationId) async {
    final all = await list();
    return all.where((c) => c.id == conversationId).firstOrNull;
  }

  /// Les 100 derniers messages, en temps réel (du plus récent au plus ancien).
  Stream<List<ChatMessage>> stream(String conversationId) => supa
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at', ascending: false)
      .limit(100)
      .map((rows) => rows.map(ChatMessage.fromMap).toList());

  Future<List<ChatMessage>> older(String conversationId, DateTime before) async {
    final data = await supa.from('messages').select().eq('conversation_id', conversationId)
        .lt('created_at', before.toUtc().toIso8601String())
        .order('created_at', ascending: false).limit(50);
    return _rows(data).map(ChatMessage.fromMap).toList();
  }

  String newClientId() => _uuid.v4();

  /// Envoi idempotent : un renvoi après coupure ne crée pas de doublon.
  Future<void> send({
    required String conversationId,
    required String clientMessageId,
    String type = 'text',
    String? body,
    String? attachmentPath,
    String? attachmentMime,
    int? attachmentSize,
    int? durationMs,
  }) async {
    try {
      await supa.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': currentUserId,
        'client_message_id': clientMessageId,
        'type': type,
        'body': body,
        'attachment_path': attachmentPath,
        'attachment_mime': attachmentMime,
        'attachment_size': attachmentSize,
        'duration_ms': durationMs,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') return; // déjà enregistré lors d'une tentative précédente
      rethrow;
    }
  }

  Future<String> uploadAttachment(String conversationId, Uint8List bytes, String mime, String ext) async {
    final path = '$conversationId/${_uuid.v4()}.$ext';
    await supa.storage.from('message-attachments')
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
    return path;
  }

  Future<String> signedUrl(String path) async {
    final cached = _signedUrlCache[path];
    if (cached != null) return cached;
    final url = await supa.storage.from('message-attachments').createSignedUrl(path, 3600);
    _signedUrlCache[path] = url;
    return url;
  }

  Future<void> markRead(String conversationId) async {
    try {
      await supa.rpc('mark_conversation_read', params: {'p_conv': conversationId});
    } catch (_) {}
  }

  Future<void> block(String userId) async {
    await supa.from('user_blocks').upsert({'blocker_id': currentUserId, 'blocked_id': userId});
  }

  Future<void> unblock(String userId) async {
    await supa.from('user_blocks').delete().eq('blocker_id', currentUserId!).eq('blocked_id', userId);
  }

  Future<bool> isBlocked(String userId) async {
    final data = await supa.from('user_blocks').select('blocked_id')
        .eq('blocker_id', currentUserId!).eq('blocked_id', userId).maybeSingle();
    return data != null;
  }
}

// ═════════════ Signalements ═════════════
class ReportRepo {
  static Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? description,
    List<String> messageIds = const [],
  }) async {
    await supa.rpc('report_content', params: {
      'p_target_type': targetType,
      'p_target_id': targetId,
      'p_reason': reason,
      'p_description': description,
      'p_message_ids': messageIds,
    });
  }
}

// ═════════════ Notifications ═════════════
class NotificationRepo {
  NotificationRepo._();
  static final instance = NotificationRepo._();

  Future<List<AppNotification>> list({List<String>? types}) async {
    var q = supa.from('notifications').select().eq('user_id', currentUserId!);
    if (types != null) q = q.inFilter('type', types);
    final data = await q.order('created_at', ascending: false).limit(100);
    return _rows(data).map(AppNotification.fromMap).toList();
  }

  Future<void> markRead(String id) async {
    await supa.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  Future<void> markAllRead() async {
    await supa.from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', currentUserId!)
        .isFilter('read_at', null);
  }

  Future<({int messages, int notifications})> unreadCounts() async {
    final data = await supa.rpc('get_unread_counts');
    final rows = _rows(data);
    if (rows.isEmpty) return (messages: 0, notifications: 0);
    return (
      messages: (rows.first['messages'] as num?)?.toInt() ?? 0,
      notifications: (rows.first['notifications'] as num?)?.toInt() ?? 0,
    );
  }

  RealtimeChannel subscribe(void Function() onChange) {
    final uid = currentUserId!;
    return supa
        .channel('unread-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
          callback: (_) => onChange(),
        )
        .subscribe();
  }
}

// ═════════════ Compte ═════════════
class AccountRepo {
  AccountRepo._();
  static final instance = AccountRepo._();

  /// Connexion par code reçu par e-mail (gratuit).
  Future<void> sendEmailOtp(String email) => supa.auth.signInWithOtp(email: email, shouldCreateUser: true);

  Future<void> verifyEmailOtp(String email, String code, {String mode = 'login'}) async {
    final type = switch (mode) {
      'signup' => OtpType.signup,
      'recovery' => OtpType.recovery,
      _ => OtpType.email,
    };
    await supa.auth.verifyOTP(type: type, email: email, token: code);
  }

  // ───── Mot de passe ─────
  Future<void> signInWithPassword(String email, String password) async {
    await supa.auth.signInWithPassword(email: email, password: password);
  }

  /// Création de compte. Renvoie true si un code de confirmation a été envoyé par e-mail
  /// (false = compte connecté immédiatement). Lève 'already_registered' si l'e-mail existe déjà.
  Future<bool> signUpWithPassword(String email, String password, {String? fullName}) async {
    final res = await supa.auth.signUp(
      email: email,
      password: password,
      data: fullName == null ? null : {'full_name': fullName},
    );
    final identities = res.user?.identities;
    if (res.user != null && identities != null && identities.isEmpty) throw const AuthException('already_registered');
    return res.session == null;
  }

  Future<void> sendPasswordReset(String email) => supa.auth.resetPasswordForEmail(email);

  Future<void> resendSignupCode(String email) => supa.auth.resend(type: OtpType.signup, email: email);

  Future<void> updatePassword(String password) async {
    await supa.auth.updateUser(UserAttributes(password: password));
  }

  /// Code par WhatsApp (moins cher et plus fiable en Guinée) ou par SMS.
  Future<void> sendOtp(String phone, {bool whatsapp = false}) => supa.auth.signInWithOtp(
        phone: phone,
        channel: whatsapp ? OtpChannel.whatsapp : OtpChannel.sms,
      );

  Future<void> verifyOtp(String phone, String code) async {
    await supa.auth.verifyOTP(type: OtpType.sms, phone: phone, token: code);
  }

  Future<void> completeSetup({required String fullName, required String role}) async {
    final uid = currentUserId!;
    await supa.from('profiles').update({'full_name': fullName.trim()}).eq('id', uid);
    await supa.from('user_consents').insert([
      {'user_id': uid, 'consent_type': 'terms', 'policy_version': AppConfig.termsVersion, 'granted': true},
      {'user_id': uid, 'consent_type': 'privacy', 'policy_version': AppConfig.termsVersion, 'granted': true},
    ]);
    await supa.rpc('activate_role', params: {'p_role': role});
  }

  Future<void> recordConsent(String type, bool granted) async {
    final uid = currentUserId;
    if (uid == null) return;
    await supa.from('user_consents').insert(
        {'user_id': uid, 'consent_type': type, 'policy_version': AppConfig.termsVersion, 'granted': granted});
  }

  Future<Map<String, dynamic>?> preferences() async =>
      supa.from('user_preferences').select().eq('user_id', currentUserId!).maybeSingle();

  Future<void> updatePreferences(Map<String, dynamic> values) async {
    await supa.from('user_preferences').update(values).eq('user_id', currentUserId!);
  }

  Future<void> updateName(String name) async {
    await supa.from('profiles').update({'full_name': name.trim()}).eq('id', currentUserId!);
  }

  Future<String> uploadPublicImage(String bucket, Uint8List bytes, String folder) async {
    final path = '${currentUserId!}/$folder/${_uuid.v4()}.jpg';
    await supa.storage.from(bucket).uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    return path;
  }

  Future<void> deleteAccount() async {
    await supa.rpc('delete_my_account');
    try {
      await supa.functions.invoke('delete-account');
    } catch (_) {/* la suppression auth sera rejouée par l'équipe si la fonction est indisponible */}
    await supa.auth.signOut();
  }
}

// ═════════════ Géolocalisation (facultative) ═════════════
enum GeoResult { ok, denied, serviceDisabled }

class GeoService {
  static Future<(GeoResult, double?, double?)> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return (GeoResult.serviceDisabled, null, null);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return (GeoResult.denied, null, null);
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 20)),
    );
    // Position arrondie (~100 m) : on n'a pas besoin de plus pour trier par distance.
    double round(double v) => (v * 1000).roundToDouble() / 1000;
    return (GeoResult.ok, round(pos.latitude), round(pos.longitude));
  }
}
