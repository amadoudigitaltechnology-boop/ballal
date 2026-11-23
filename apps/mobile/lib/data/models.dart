// Modèles de données BALLAL — correspondent aux tables et RPC Supabase.

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v as String);
double? _double(dynamic v) => v == null ? null : (v as num).toDouble();
int? _int(dynamic v) => v == null ? null : (v as num).toInt();
List<String> _strings(dynamic v) => v == null ? const [] : (v as List).map((e) => e.toString()).toList();

class Category {
  Category({required this.id, required this.name, required this.slug, this.parentId, this.icon});
  final String id;
  final String name;
  final String slug;
  final String? parentId;
  final String? icon;

  bool get isFamily => parentId == null;

  factory Category.fromMap(Map<String, dynamic> m) => Category(
        id: m['id'] as String,
        name: m['name'] as String,
        slug: m['slug'] as String,
        parentId: m['parent_id'] as String?,
        icon: m['icon'] as String?,
      );
}

class Place {
  Place({required this.id, required this.name, required this.level, this.parentId, this.lat, this.lng});
  final String id;
  final String name;
  final String level; // country, region, prefecture, city, commune, quartier
  final String? parentId;
  final double? lat;
  final double? lng;

  factory Place.fromMap(Map<String, dynamic> m) => Place(
        id: m['id'] as String,
        name: m['name'] as String,
        level: m['level'] as String,
        parentId: m['parent_id'] as String?,
        lat: _double(m['lat']),
        lng: _double(m['lng']),
      );
}

/// Carte de résultat renvoyée par search_professionals / recommend_professionals.
class ProCard {
  ProCard({
    required this.id,
    required this.displayName,
    required this.headline,
    this.slug,
    this.logoPath,
    this.locationName,
    required this.availability,
    required this.ratingAvg,
    required this.ratingCount,
    required this.identityVerified,
    required this.companyVerified,
    required this.phoneVerified,
    this.distanceKm,
    required this.reasons,
  });

  final String id;
  final String displayName;
  final String headline;
  final String? slug;
  final String? logoPath;
  final String? locationName;
  final String availability;
  final double ratingAvg;
  final int ratingCount;
  final bool identityVerified;
  final bool companyVerified;
  final bool phoneVerified;
  final double? distanceKm;
  final List<String> reasons;

  factory ProCard.fromMap(Map<String, dynamic> m) => ProCard(
        id: m['professional_id'] as String,
        displayName: (m['display_name'] as String?) ?? '',
        headline: (m['headline'] as String?) ?? '',
        slug: m['slug'] as String?,
        logoPath: m['logo_path'] as String?,
        locationName: m['location_name'] as String?,
        availability: (m['availability'] as String?) ?? 'available',
        ratingAvg: _double(m['rating_avg']) ?? 0,
        ratingCount: _int(m['rating_count']) ?? 0,
        identityVerified: (m['identity_verified'] as bool?) ?? false,
        companyVerified: (m['company_verified'] as bool?) ?? false,
        phoneVerified: (m['phone_verified'] as bool?) ?? false,
        distanceKm: _double(m['distance_km']),
        reasons: _strings(m['reasons']),
      );
}

class ProService {
  ProService({
    required this.id,
    required this.professionalId,
    required this.title,
    required this.description,
    this.categoryId,
    this.priceMin,
    this.priceMax,
    this.priceUnit,
    this.durationText,
    required this.status,
    this.photos = const [],
  });

  final String id;
  final String professionalId;
  final String title;
  final String description;
  final String? categoryId;
  final int? priceMin;
  final int? priceMax;
  final String? priceUnit;
  final String? durationText;
  final String status;
  final List<String> photos; // chemins dans le bucket pro-media

  factory ProService.fromMap(Map<String, dynamic> m) => ProService(
        id: m['id'] as String,
        professionalId: m['professional_id'] as String,
        title: m['title'] as String,
        description: (m['description'] as String?) ?? '',
        categoryId: m['category_id'] as String?,
        priceMin: _int(m['price_min']),
        priceMax: _int(m['price_max']),
        priceUnit: m['price_unit'] as String?,
        durationText: m['duration_text'] as String?,
        status: m['status'] as String,
        photos: (((m['service_media'] as List?) ?? const [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
              ..sort((a, b) => ((a['sort_order'] as num?) ?? 0).compareTo((b['sort_order'] as num?) ?? 0)))
            .map((e) => e['storage_path'] as String)
            .toList(),
      );
}

class Review {
  Review({required this.id, required this.rating, this.comment, required this.createdAt, this.authorName, this.reply});
  final String id;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String? authorName;
  final String? reply;

  factory Review.fromMap(Map<String, dynamic> m) {
    final replies = m['review_replies'];
    String? reply;
    if (replies is Map<String, dynamic>) reply = replies['body'] as String?;
    if (replies is List && replies.isNotEmpty) reply = (replies.first as Map<String, dynamic>)['body'] as String?;
    final author = m['author'];
    return Review(
      id: m['id'] as String,
      rating: _int(m['rating']) ?? 0,
      comment: m['comment'] as String?,
      createdAt: _date(m['created_at']) ?? DateTime.now(),
      authorName: author is Map<String, dynamic> ? author['full_name'] as String? : null,
      reply: reply,
    );
  }
}

/// Profil public complet d'un professionnel.
class ProDetail {
  ProDetail({
    required this.id,
    required this.displayName,
    required this.headline,
    required this.description,
    required this.proType,
    this.logoPath,
    this.coverPath,
    this.experienceYears,
    required this.languages,
    required this.skills,
    this.locationName,
    required this.availability,
    this.priceHint,
    required this.identityVerified,
    required this.companyVerified,
    required this.ratingAvg,
    required this.ratingCount,
    required this.isPublished,
    required this.areas,
    required this.categories,
    required this.hours,
    this.lat,
    this.lng,
  });

  final String id;
  final String displayName;
  final String headline;
  final String description;
  final String proType;
  final String? logoPath;
  final String? coverPath;
  final int? experienceYears;
  final List<String> languages;
  final List<String> skills;
  final String? locationName;
  final String availability;
  final String? priceHint;
  final bool identityVerified;
  final bool companyVerified;
  final double ratingAvg;
  final int ratingCount;
  final bool isPublished;
  final List<String> areas;
  final List<Category> categories;
  final List<OpeningHour> hours;
  final double? lat;
  final double? lng;

  factory ProDetail.fromMap(Map<String, dynamic> m) {
    final loc = m['location'];
    return ProDetail(
      id: m['user_id'] as String,
      displayName: (m['display_name'] as String?) ?? '',
      headline: (m['headline'] as String?) ?? '',
      description: (m['description'] as String?) ?? '',
      proType: (m['pro_type'] as String?) ?? 'independent',
      logoPath: m['logo_path'] as String?,
      coverPath: m['cover_path'] as String?,
      experienceYears: _int(m['experience_years']),
      languages: _strings(m['languages']),
      skills: _strings(m['skills']),
      locationName: loc is Map<String, dynamic> ? loc['name'] as String? : null,
      availability: (m['availability'] as String?) ?? 'available',
      priceHint: m['price_hint'] as String?,
      identityVerified: (m['identity_verified'] as bool?) ?? false,
      companyVerified: (m['company_verified'] as bool?) ?? false,
      ratingAvg: _double(m['rating_avg']) ?? 0,
      ratingCount: _int(m['rating_count']) ?? 0,
      isPublished: (m['is_published'] as bool?) ?? false,
      areas: ((m['service_areas'] as List?) ?? const [])
          .map((a) => ((a as Map<String, dynamic>)['location'] as Map<String, dynamic>?)?['name'] as String?)
          .whereType<String>()
          .toList(),
      categories: ((m['professional_categories'] as List?) ?? const [])
          .map((c) => (c as Map<String, dynamic>)['category'])
          .whereType<Map<String, dynamic>>()
          .map(Category.fromMap)
          .toList(),
      hours: ((m['opening_hours'] as List?) ?? const [])
          .map((h) => OpeningHour.fromMap(h as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.weekday.compareTo(b.weekday)),
      lat: _double(m['lat']),
      lng: _double(m['lng']),
    );
  }
}

class OpeningHour {
  OpeningHour({required this.weekday, required this.opens, required this.closes});
  final int weekday; // 0 = lundi
  final String opens;
  final String closes;

  factory OpeningHour.fromMap(Map<String, dynamic> m) => OpeningHour(
        weekday: _int(m['weekday']) ?? 0,
        opens: (m['opens'] as String).substring(0, 5),
        closes: (m['closes'] as String).substring(0, 5),
      );
}

class ServiceRequest {
  ServiceRequest({
    required this.id,
    required this.clientId,
    required this.professionalId,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    this.desiredDate,
    this.budgetMin,
    this.budgetMax,
    this.locationName,
    this.addressHint,
    this.clientName,
    this.proName,
    this.hasReview = false,
  });

  final String id;
  final String clientId;
  final String professionalId;
  final String title;
  final String description;
  final String status;
  final DateTime createdAt;
  final DateTime? desiredDate;
  final int? budgetMin;
  final int? budgetMax;
  final String? locationName;
  final String? addressHint;
  final String? clientName;
  final String? proName;
  final bool hasReview;

  factory ServiceRequest.fromMap(Map<String, dynamic> m) {
    final loc = m['location'];
    final client = m['client'];
    final pro = m['pro'];
    final reviews = m['reviews'];
    return ServiceRequest(
      id: m['id'] as String,
      clientId: m['client_id'] as String,
      professionalId: m['professional_id'] as String,
      title: m['title'] as String,
      description: m['description'] as String,
      status: m['status'] as String,
      createdAt: _date(m['created_at']) ?? DateTime.now(),
      desiredDate: _date(m['desired_date']),
      budgetMin: _int(m['budget_min']),
      budgetMax: _int(m['budget_max']),
      locationName: loc is Map<String, dynamic> ? loc['name'] as String? : null,
      addressHint: m['address_hint'] as String?,
      clientName: client is Map<String, dynamic> ? client['full_name'] as String? : null,
      proName: pro is Map<String, dynamic> ? pro['display_name'] as String? : null,
      hasReview: reviews is List ? reviews.isNotEmpty : reviews is Map,
    );
  }
}

class StatusChange {
  StatusChange({required this.toStatus, required this.createdAt, this.note});
  final String toStatus;
  final DateTime createdAt;
  final String? note;

  factory StatusChange.fromMap(Map<String, dynamic> m) => StatusChange(
        toStatus: m['to_status'] as String,
        createdAt: _date(m['created_at']) ?? DateTime.now(),
        note: (m['note'] as String?)?.trim().isEmpty ?? true ? null : m['note'] as String,
      );
}

class ConversationSummary {
  ConversationSummary({
    required this.id,
    this.requestId,
    required this.otherUserId,
    required this.otherName,
    this.otherAvatar,
    required this.otherIsPro,
    this.lastMessageAt,
    this.lastMessagePreview,
    required this.unreadCount,
    this.otherLastReadAt,
  });

  final String id;
  final String? requestId;
  final String otherUserId;
  final String otherName;
  final String? otherAvatar;
  final bool otherIsPro;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final int unreadCount;
  final DateTime? otherLastReadAt;

  factory ConversationSummary.fromMap(Map<String, dynamic> m) => ConversationSummary(
        id: m['conversation_id'] as String,
        requestId: m['request_id'] as String?,
        otherUserId: m['other_user_id'] as String,
        otherName: (m['other_name'] as String?) ?? '',
        otherAvatar: m['other_avatar'] as String?,
        otherIsPro: (m['other_is_pro'] as bool?) ?? false,
        lastMessageAt: _date(m['last_message_at']),
        lastMessagePreview: m['last_message_preview'] as String?,
        unreadCount: _int(m['unread_count']) ?? 0,
        otherLastReadAt: _date(m['other_last_read_at']),
      );
}

enum SendState { sending, sent, failed }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    this.body,
    this.attachmentPath,
    this.attachmentMime,
    this.durationMs,
    required this.createdAt,
    this.clientMessageId,
    this.sendState = SendState.sent,
    this.localBytes,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String type; // text, image, audio
  final String? body;
  final String? attachmentPath;
  final String? attachmentMime;
  final int? durationMs;
  final DateTime createdAt;
  final String? clientMessageId;
  SendState sendState;
  final List<int>? localBytes; // aperçu local avant envoi

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: m['id'] as String,
        conversationId: m['conversation_id'] as String,
        senderId: m['sender_id'] as String,
        type: m['type'] as String,
        body: m['body'] as String?,
        attachmentPath: m['attachment_path'] as String?,
        attachmentMime: m['attachment_mime'] as String?,
        durationMs: _int(m['duration_ms']),
        createdAt: _date(m['created_at']) ?? DateTime.now(),
        clientMessageId: m['client_message_id'] as String?,
      );
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.entityType,
    this.entityId,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String? body;
  final String? entityType;
  final String? entityId;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as String,
        type: m['type'] as String,
        title: m['title'] as String,
        body: m['body'] as String?,
        entityType: m['entity_type'] as String?,
        entityId: m['entity_id'] as String?,
        readAt: _date(m['read_at']),
        createdAt: _date(m['created_at']) ?? DateTime.now(),
      );
}

/// Filtres de recherche (écran Recherche).
class SearchFilters {
  SearchFilters({
    this.query = '',
    this.category,
    this.place,
    this.lat,
    this.lng,
    this.radiusKm,
    this.availableOnly = false,
    this.verifiedOnly = false,
    this.minRating,
    this.sort = 'relevance',
  });

  String query;
  Category? category;
  Place? place;
  double? lat;
  double? lng;
  int? radiusKm;
  bool availableOnly;
  bool verifiedOnly;
  double? minRating;
  String sort;

  bool get usesGps => lat != null && lng != null;

  int get activeCount =>
      (category != null ? 1 : 0) +
      (place != null ? 1 : 0) +
      (usesGps ? 1 : 0) +
      (availableOnly ? 1 : 0) +
      (verifiedOnly ? 1 : 0) +
      (minRating != null ? 1 : 0);

  SearchFilters copy() => SearchFilters(
        query: query,
        category: category,
        place: place,
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        availableOnly: availableOnly,
        verifiedOnly: verifiedOnly,
        minRating: minRating,
        sort: sort,
      );
}
